// 画面の層（Next.js の app/）。組み立てだけを行い、取得や選別の処理を書かない。

import { createRuntimeDeps, createXPostDeps, isFixtureMode } from "@/composition/runtime";
import { buildNewsSections } from "@/services/news-sections";
import { applyMinScore, MIN_SCORE_QUERY_NAME } from "@/services/score-filter";
import { getTodayNews } from "@/services/today-news";
import { getXPostsByItem } from "@/services/x-posts";
import { FixtureNotice } from "@/ui/FixtureNotice";
import { MinScoreNotice } from "@/ui/MinScoreNotice";
import { NewsSections } from "@/ui/NewsSections";

export const dynamic = "force-dynamic";

type Props = {
  /** URL のクエリ（Next.js 16 の頁の searchParams。Promise で渡る）。引数なしの呼び出しも受け付けるため省略できる。 */
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

export default async function Home({ searchParams }: Props = {}) {
  const query = (await searchParams) ?? {};
  const { items: filtered, minScore } = applyMinScore(
    await getTodayNews(createRuntimeDeps()),
    query[MIN_SCORE_QUERY_NAME],
  );
  const { sections, items } = buildNewsSections(filtered);
  // 表示の順の記事を渡し、画面の上にある記事の投稿から埋め込みを問い合わせる。
  const xPosts = await getXPostsByItem(items, createXPostDeps());
  return (
    <main style={{ maxWidth: 720, margin: "0 auto", padding: "2rem 1rem" }}>
      <FixtureNotice active={isFixtureMode()} />
      <h1>AI News Today</h1>
      <MinScoreNotice minScore={minScore} />
      <NewsSections sections={sections} xPosts={xPosts} />
    </main>
  );
}
