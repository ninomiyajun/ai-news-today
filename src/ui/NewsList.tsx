// 表示の部品の層。受け取った記事を表示するだけで、取得や選別はしない。

import type { NewsItem, XPostEmbed } from "@/domain/news";
import { XPostCard, XWidgetsScript } from "@/ui/XPostEmbed";

type Props = {
  items: readonly NewsItem[];
  /** 記事の id から、その記事の下に表示する X の投稿の埋め込みの情報への対応。省略すると表示しない。 */
  xPosts?: Readonly<Record<string, readonly XPostEmbed[]>>;
};

export function NewsList({ items, xPosts = {} }: Props) {
  if (items.length === 0) {
    return <p>表示できる記事はまだありません。</p>;
  }
  const hasEmbeds = items.some((item) => (xPosts[item.id]?.length ?? 0) > 0);
  return (
    <>
      <ul>
        {items.map((item) => {
          const embeds = xPosts[item.id] ?? [];
          return (
            <li key={item.id}>
              <a href={item.url} target="_blank" rel="noopener noreferrer">
                {item.title}
              </a>{" "}
              <small>({item.score})</small>
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
      {hasEmbeds && <XWidgetsScript />}
    </>
  );
}
