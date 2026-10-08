// 表示の部品の層。受け取った記事を表示するだけで、取得や選別はしない。
// 1 つの節の記事の一覧を描く。0 件のときの文言と X の埋め込みのスクリプトは、画面に 1 つだけ置く NewsSections が描く。

import type { NewsItem, XPostEmbed } from "@/domain/news";
import { scoreText } from "@/ui/source-labels";
import { XPostCard } from "@/ui/XPostEmbed";

type Props = {
  items: readonly NewsItem[];
  /** 記事の id から、その記事の下に表示する X の投稿の埋め込みの情報への対応。省略すると表示しない。 */
  xPosts?: Readonly<Record<string, readonly XPostEmbed[]>>;
};

export function NewsList({ items, xPosts = {} }: Props) {
  return (
    <ul>
      {items.map((item) => {
        const embeds = xPosts[item.id] ?? [];
        return (
          <li key={item.id}>
            <a href={item.url} target="_blank" rel="noopener noreferrer">
              {item.title}
            </a>{" "}
            <small>{scoreText(item.source, item.score)}</small>
            {embeds.length > 0 && (
              <div>
                {embeds.map((embed) => (
                  <XPostCard key={embed.postUrl} embed={embed} />
                ))}
              </div>
            )}
          </li>
        );
      })}
    </ul>
  );
}
