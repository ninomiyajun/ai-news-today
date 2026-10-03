// 画面の層（Next.js の app/）。組み立てだけを行い、取得や選別の処理を書かない。

import { createRuntimeDeps } from "@/composition/runtime";
import { getTodayNews } from "@/services/today-news";
import { NewsList } from "@/ui/NewsList";

export const dynamic = "force-dynamic";

export default async function Home() {
  const items = await getTodayNews(createRuntimeDeps());
  return (
    <main style={{ maxWidth: 720, margin: "0 auto", padding: "2rem 1rem" }}>
      <h1>AI News Today</h1>
      <NewsList items={items} />
    </main>
  );
}
