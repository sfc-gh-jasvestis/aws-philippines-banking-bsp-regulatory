"""Publish simulated source-feed load events to Amazon Data Firehose (stream <prefix>-events).

Each event is one source-system extract loaded for a reporting unit's regulatory
returns: the balance loaded (PHP) and the number of failed validation checks.
Firehose batches the records into S3 (events/); Snowpipe loads them into RAW.LIVE_EVENTS.
Reporting unit IDs come from RAW.REPORTING_UNITS (RU-0000..RU-0039). Values are seeded random.
"""
import argparse
import json
import random
import time
from datetime import datetime, timezone

SOURCE_SYSTEMS = ('Loan origination system', 'Core deposit system', 'Risk-weighted asset engine',
                  'Treasury and ALM system', 'General ledger')


def make_event(rng):
    alert = rng.random() < 0.1
    source_system = rng.choice(SOURCE_SYSTEMS)
    balance = round((90000000 if alert else 25000000) * rng.lognormvariate(0, 0.6), 2)
    return {'unit_id': f'RU-{rng.randint(0, 39):04d}',
            'event_ts': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'source_system': source_system,
            'balance_php': balance,
            'failed_checks': max(0, round((5 if alert else 0) + rng.gauss(0, 0.8))),
            'status': 'ALERT' if alert else 'OK',
            'sent_ms': int(time.time() * 1000)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--prefix', default='ph-banking-bsp-regulatory')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    firehose = boto3.client('firehose', region_name=args.region)
    stream = f'{args.prefix}-events'
    rng = random.Random(args.seed)
    records = [{'Data': (json.dumps(make_event(rng)) + '\n').encode()} for _ in range(args.count)]
    for start in range(0, len(records), 500):
        out = firehose.put_record_batch(DeliveryStreamName=stream, Records=records[start:start + 500])
        if out['FailedPutCount']:
            raise RuntimeError(f"{out['FailedPutCount']} records were rejected by Firehose")
    print(f'published {args.count} source-feed load events to Firehose stream {stream}; S3 delivery buffers up to 60 s')


if __name__ == '__main__':
    main()
