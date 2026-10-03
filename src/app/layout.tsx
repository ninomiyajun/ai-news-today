import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AI News Today",
  description: "AI に関する今日のニュース（手元の PC で本人だけが見る）",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
