import type { Metadata } from "next";
import { Manrope, Space_Grotesk } from "next/font/google";
import "@/app/globals.css";

const manrope = Manrope({
  subsets: ["latin"],
  variable: "--font-body"
});

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-display"
});

export const metadata: Metadata = {
  title: "IntelliLead by Intellium Digital",
  description: "Smart lead tracking for growing businesses.",
  metadataBase: new URL("https://intelliumdigital.online")
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html className={`${manrope.variable} ${spaceGrotesk.variable}`} lang="en">
      <body className="font-[var(--font-body)]">{children}</body>
    </html>
  );
}
