// 整形・選別の層。文字列と記事から X の投稿の URL を抜き出し、正規の形にそろえる純粋な関数を置く。

import type { NewsItem } from "@/domain/news";

/** 1 記事あたりに表示する X の投稿の上限（計画の判断の記録の 4） */
export const MAX_X_POSTS_PER_ITEM = 3;

// 候補の切り出し: http:// か https:// で始まり、ASCII の URL に使える文字が続く範囲。
// 日本語などの ASCII でない文字と空白で範囲が終わる。
const URL_CANDIDATE = /https?:\/\/[A-Za-z0-9\-._~:/?#[\]@!$&'()*+,;=%]+/gi;
// 文の中の URL の直後に続きやすい句読点と閉じ括弧。候補の末尾から落とす（例: 「(https://x.com/a/status/1)」）。
const TRAILING_PUNCTUATION = /[.,;:!?)\]'*]+$/;

const X_HOSTS = new Set(["x.com", "www.x.com", "mobile.x.com", "twitter.com", "www.twitter.com", "mobile.twitter.com"]);

const SCREEN_NAME = /^[A-Za-z0-9_]{1,15}$/;
const POST_ID = /^[0-9]+$/;

/** 1 つの URL の文字列を、X の投稿の URL の正規の形にする。投稿の URL でなければ null。 */
function toCanonicalPostUrl(candidate: string): string | null {
  let url: URL;
  try {
    url = new URL(candidate);
  } catch {
    return null;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  if (!X_HOSTS.has(url.hostname.toLowerCase())) return null;
  const [screenName, status, id] = url.pathname.split("/").filter((part) => part.length > 0);
  if (screenName === undefined || status !== "status" || id === undefined) return null;
  if (!SCREEN_NAME.test(screenName) || screenName.toLowerCase() === "i") return null;
  if (!POST_ID.test(id)) return null;
  return `https://x.com/${screenName}/status/${id}`;
}

/** 文字列に含まれる X の投稿の URL を、正規の形で、出てきた順に返す（重複は除かない）。 */
export function extractXPostUrls(text: string): string[] {
  const result: string[] = [];
  for (const match of text.matchAll(URL_CANDIDATE)) {
    const canonical = toCanonicalPostUrl(match[0].replace(TRAILING_PUNCTUATION, ""));
    if (canonical !== null) result.push(canonical);
  }
  return result;
}

/**
 * 正規の形の投稿の URL から投稿の id を返す。同じ投稿かどうかは id で判定する。利用者名は大文字と小文字を
 * 区別せず、変更もされうるので、URL の文字列のままでは同じ投稿を別のものと数えてしまうためである。
 */
export function xPostIdOf(canonicalUrl: string): string {
  return canonicalUrl.slice(canonicalUrl.lastIndexOf("/") + 1);
}

/**
 * 記事の URL、添えた文章の順に X の投稿の URL を抜き出し、同じ投稿（同じ id）を 1 回だけ数えて
 * 最初に出てきた URL を残し、先頭の MAX_X_POSTS_PER_ITEM 件を返す。
 */
export function xPostUrlsOfItem(item: NewsItem): string[] {
  const byId = new Map<string, string>();
  for (const source of [item.url, item.text ?? ""]) {
    for (const url of extractXPostUrls(source)) {
      const id = xPostIdOf(url);
      if (!byId.has(id)) byId.set(id, url);
    }
  }
  return [...byId.values()].slice(0, MAX_X_POSTS_PER_ITEM);
}
