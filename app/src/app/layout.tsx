import type { Metadata } from 'next';
import '@/globals.css';

export const metadata: Metadata = {
  title: 'Philippine Bank Regulatory Reporting',
  description: 'Snowflake + AWS Demo Application',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-slate-50 antialiased">{children}</body>
    </html>
  );
}
