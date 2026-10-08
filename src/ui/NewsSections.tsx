// 表示の部品の層。受け取った節を、そのままの順で表示するだけで、判定や並べ替えはしない。
// 画面に 1 つだけ出すもの（すべての節が 0 件のときの文言と、X の埋め込みのスクリプト）は、この部品が描く。

import type { NewsSection, XPostEmbed } from "@/domain/news";
import { NewsList } from "@/ui/NewsList";
import { sectionHeadingText } from "@/ui/source-labels";
import { XWidgetsScript } from "@/ui/XPostEmbed";

type Props = {
  sections: readonly NewsSection[];
  /** 記事の id から、その記事の下に表示する X の投稿の埋め込みの情報への対応。省略すると表示しない。 */
  xPosts?: Readonly<Record<string, readonly XPostEmbed[]>>;
};

export function NewsSections({ sections, xPosts = {} }: Props) {
  if (sections.length === 0) {
    return <p>表示できる記事はまだありません。</p>;
  }
  const hasEmbeds = sections.some((section) =>
    section.items.some((item) => (xPosts[item.id]?.length ?? 0) > 0),
  );
  return (
    <>
      {sections.map(({ source, items }) => (
        <section key={source} aria-labelledby={`news-section-${source}`}>
          <h2 id={`news-section-${source}`}>{sectionHeadingText(source, items.length)}</h2>
          <NewsList items={items} xPosts={xPosts} />
        </section>
      ))}
      {hasEmbeds && <XWidgetsScript />}
    </>
  );
}
