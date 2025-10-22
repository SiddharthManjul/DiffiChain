import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Providers } from '@/components/Providers';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'DiffiChain - Confidential Token Launchpad',
  description: 'Launch and trade confidential tokens using zero-knowledge proofs',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        {/* Load snarkjs for zero-knowledge proof generation */}
        <script src="https://cdn.jsdelivr.net/npm/snarkjs@latest/build/snarkjs.min.js" async></script>
      </head>
      <body className={inter.className}>
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}
