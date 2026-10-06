// 画面の層（Next.js の app/）。組み立てだけを行い、取得や選別の処理を書かない。

import { createRuntimeDeps, createXPostDeps } from "@/composition/runtime";
import { getTodayNews } from "@/services/today-news";
import { getXPostsByItem } from "@/services/x-posts";
import { NewsList } from "@/ui/NewsList";

export const dynamic = "force-dynamic";

export default async function Home() {
  const items = await getTodayNews(createRuntimeDeps());
  const xPosts = await getXPostsByItem(items, createXPostDeps());
  return (
    <main style={{ maxWidth: 720, margin: "0 auto", padding: "2rem 1rem" }}>
      <h1>AI News Today</h1>
      <NewsList items={items} xPosts={xPosts} />
    </main>
  );
}
