// 処理の流れの層。記事の一覧から X の投稿の URL を集め、oEmbed で確かめた埋め込みの情報を記事ごとに束ねる。
// 依存（HttpClient）は引数で受け取り、自分では作らない。getTodayNews とは別の関数にしている（既存の形を変えないため）。

import { xPostIdOf, xPostUrlsOfItem } from "@/curation/x-post-url";
import type { NewsItem, XPostEmbed } from "@/domain/news";
import type { HttpClient } from "@/ports/http";
import { fetchXPostEmbed } from "@/sources/x-oembed";

export type XPostDeps = {
  http: HttpClient;
};

/** 画面全体で oEmbed に問い合わせる一意の投稿の URL の上限（計画の判断の記録の 4、8） */
export const MAX_X_POSTS_TOTAL = 10;

/** 記事の id から、その記事に添えて表示する埋め込みの情報の配列への対応 */
export type XPostsByItemId = Record<string, XPostEmbed[]>;

/**
 * 記事の順、記事の中では出てきた順に一意の投稿（投稿の id で判定し、最初に出てきた URL を残す）を並べ、
 * 先頭の MAX_X_POSTS_TOTAL 件だけを oEmbed に 1 回ずつ（並べて）問い合わせる。結果を、その投稿を含む各記事へ
 * 対応付ける。取得できなかった投稿は含めない。
 */
export async function getXPostsByItem(items: readonly NewsItem[], deps: XPostDeps): Promise<XPostsByItemId> {
  const urlsByItem = items.map((item) => ({ id: item.id, urls: xPostUrlsOfItem(item) }));

  // 投稿の id から、最初に出てきた正規の形の URL への対応（挿入の順が取得の順になる）
  const firstUrlByPostId = new Map<string, string>();
  for (const { urls } of urlsByItem) {
    for (const url of urls) {
      const postId = xPostIdOf(url);
      if (!firstUrlByPostId.has(postId)) firstUrlByPostId.set(postId, url);
    }
  }
  const fetched = [...firstUrlByPostId.entries()].slice(0, MAX_X_POSTS_TOTAL);

  const embeds = await Promise.all(fetched.map(([, url]) => fetchXPostEmbed(deps.http, url)));
  const embedByPostId = new Map<string, XPostEmbed>();
  fetched.forEach(([postId], i) => {
    const embed = embeds[i];
    if (embed !== null) embedByPostId.set(postId, embed);
  });

  const result: XPostsByItemId = {};
  for (const { id, urls } of urlsByItem) {
    result[id] = urls.flatMap((url) => {
      const embed = embedByPostId.get(xPostIdOf(url));
      return embed === undefined ? [] : [embed];
    });
  }
  return result;
}
