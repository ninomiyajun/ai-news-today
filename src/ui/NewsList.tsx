// 表示の部品の層。受け取った記事を表示するだけで、取得や選別はしない。

import type { NewsItem } from "@/domain/news";

export function NewsList({ items }: { items: readonly NewsItem[] }) {
  if (items.length === 0) {
    return <p>表示できる記事はまだありません。</p>;
  }
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>
          <a href={item.url} target="_blank" rel="noopener noreferrer">
            {item.title}
          </a>{" "}
          <small>({item.score})</small>
        </li>
      ))}
    </ul>
  );
}
