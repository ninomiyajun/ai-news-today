// 取得の層。X の oEmbed の入口に問い合わせ、投稿が存在して公開されていることを確かめ、投稿者の名前を得る。
// 応答の html は使わない（外から受け取った HTML を画面に入れないため。ARCHITECTURE.md の将来の作りの注意）。

import type { XPostEmbed } from "@/domain/news";
import type { HttpClient } from "@/ports/http";

/**
 * X の oEmbed の入口（認証は要らない）。引数は url だけを付ける。omit_script、dnt、lang は応答の html だけを
 * 変えるもので、html を使わないので付けない（docs/adr/0003-x-post-embed.md）。
 */
export const X_OEMBED_ENDPOINT = "https://publish.x.com/oembed";

/** 正規の形の投稿の URL から、oEmbed への要求の URL を作る。 */
export function xOEmbedRequestUrl(postUrl: string): string {
  return `${X_OEMBED_ENDPOINT}?url=${encodeURIComponent(postUrl)}`;
}

/**
 * 正規の形の投稿の URL について oEmbed に問い合わせ、埋め込みの情報を返す。
 * 状態が 200 でない、JSON でない、type が "rich" でない、author_name が空でない文字列でない、
 * 要求が例外で失敗した（時間切れを含む）、のどれかのときは null を返す（表示しないだけにする）。
 */
export async function fetchXPostEmbed(http: HttpClient, postUrl: string): Promise<XPostEmbed | null> {
  let body: string;
  try {
    const res = await http.get(xOEmbedRequestUrl(postUrl));
    if (res.status !== 200) return null;
    body = res.body;
  } catch {
    return null;
  }
  let json: unknown;
  try {
    json = JSON.parse(body);
  } catch {
    return null;
  }
  if (typeof json !== "object" || json === null) return null;
  const record = json as Record<string, unknown>;
  if (record.type !== "rich") return null;
  const authorName = record.author_name;
  if (typeof authorName !== "string" || authorName.trim().length === 0) return null;
  // 前後の空白は表示に意味が無いので落として返す。
  return { postUrl, authorName: authorName.trim() };
}
