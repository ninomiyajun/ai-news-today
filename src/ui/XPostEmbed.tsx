// 表示の部品の層。X の投稿の埋め込みを表示する。
// ブラウザに読み込ませる外部のスクリプトは、このファイルの WIDGETS_JS_URL だけである（ARCHITECTURE.md の不変条件 5）。
// next/script の import は、ESLint がこのファイルの外で拒否する。

import Script from "next/script";
import type { XPostEmbed } from "@/domain/news";

/** X の埋め込みのスクリプト。blockquote.twitter-tweet を埋め込みの表示へ置き換える（docs/adr/0003-x-post-embed.md）。 */
export const WIDGETS_JS_URL = "https://platform.twitter.com/widgets.js";

/**
 * 1 件の投稿の埋め込み。widgets.js が動けば X の埋め込みの表示に置き換わり、動かなければ投稿者の名前と
 * 「X で見る」のリンク（代替の表示）が残る。oEmbed の html は使わず、React の要素で組み立てる。
 * data-dnt="true" で、この埋め込みを X が個人に合わせたおすすめや広告に使わないよう求める。
 */
export function XPostCard({ embed }: { embed: XPostEmbed }) {
  return (
    <blockquote className="twitter-tweet" data-dnt="true">
      <span>{embed.authorName}</span>{" "}
      <a href={embed.postUrl} target="_blank" rel="noopener noreferrer">
        X で見る
      </a>
    </blockquote>
  );
}

/** widgets.js を読み込む。埋め込みが 1 件以上ある画面で、1 回だけ描く。 */
export function XWidgetsScript() {
  return <Script src={WIDGETS_JS_URL} strategy="afterInteractive" />;
}
