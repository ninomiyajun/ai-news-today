// 実行時の依存を組み立てる層。本物の時計と情報源を選ぶのは、この層だけである。
// 試験では、この層を使わず、services に fixedClock と staticSource を直接渡す。
// P1 では、情報源の取得をまだ作っていないので、情報源は空にしている。

import type { TodayNewsDeps } from "@/services/today-news";
import type { XPostDeps } from "@/services/x-posts";
import { systemClock } from "@/ports/clock";
import { fetchHttpClient, withTimeout } from "@/ports/http";

/** X の oEmbed への 1 回の要求の時間切れ（ミリ秒）。画面の表示が oEmbed を待つのは、おおむねこの時間まで。 */
export const X_OEMBED_TIMEOUT_MS = 5000;

export function createRuntimeDeps(): TodayNewsDeps {
  return {
    sources: [],
    clock: systemClock,
  };
}

/** X の投稿の埋め込みの取得に使う依存。時間切れは X の埋め込みの依存だけに付ける（fetchHttpClient は変えない）。 */
export function createXPostDeps(): XPostDeps {
  return { http: withTimeout(fetchHttpClient, X_OEMBED_TIMEOUT_MS) };
}
