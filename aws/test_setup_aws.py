import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from publish_events import make_event
from setup_aws import firehose_request, ident, names


class SetupAwsTests(unittest.TestCase):
    def test_names_are_scoped_to_prefix_account_region(self):
        n = names('ph-banking-bsp-regulatory', '123456789012', 'us-west-2')
        self.assertEqual(n['bucket'], 'ph-banking-bsp-regulatory-123456789012-us-west-2')
        self.assertEqual(n['storage_int'], 'PH_BANKING_BSP_REGULATORY_S3_INT')
        self.assertEqual(n['firehose_stream'], 'ph-banking-bsp-regulatory-events')

    def test_rejects_unsafe_identifiers(self):
        for bad in ['DB; DROP', 'a-b', '1abc', '']:
            with self.assertRaises(ValueError):
                ident(bad)

    def test_firehose_request_matches_aws_schema(self):
        import botocore.session
        from botocore.validate import validate_parameters
        n = names('ph-banking-bsp-regulatory', '123456789012', 'us-west-2')
        req = firehose_request(n, n['bucket'], 'arn:aws:iam::123456789012:role/ph-banking-bsp-regulatory-firehose-s3')
        model = botocore.session.get_session().get_service_model('firehose')
        validate_parameters(req, model.operation_model('CreateDeliveryStream').input_shape)
        dest = req['ExtendedS3DestinationConfiguration']
        self.assertEqual(dest['Prefix'], 'events/')
        self.assertFalse(dest['ErrorOutputPrefix'].startswith('events/'))

    def test_feed_event_matches_pipe_columns(self):
        import random
        event = make_event(random.Random(7))
        self.assertEqual(set(event), {'unit_id', 'event_ts', 'source_system', 'balance_php', 'failed_checks', 'status', 'sent_ms'})
        self.assertRegex(event['unit_id'], r'^RU-00[0-3]\d$')
        self.assertIn(event['status'], ('ALERT', 'OK'))


if __name__ == '__main__':
    unittest.main()
