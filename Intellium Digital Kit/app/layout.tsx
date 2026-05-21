import type { Metadata } from "next";
import { DM_Sans, Space_Grotesk } from "next/font/google";

import "@/app/globals.css";

const headingFont = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-heading"
});

const bodyFont = DM_Sans({
  subsets: ["latin"],
  variable: "--font-body"
});

export const metadata: Metadata = {
  title: "IntelliLead Outreach Portal",
  description:
    "Private outreach operations portal for Intellium Digital researchers and admins."
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={`${headingFont.variable} ${bodyFont.variable}`}>
        {children}
      </body>
    </html>
  );
}
