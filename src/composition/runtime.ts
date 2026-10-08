// 実行時の依存を組み立てる層。本物の時計と情報源を選ぶのは、この層だけである。
// 試験では、この層を使わず、services に fixedClock と staticSource を直接渡す。
// P1 では、情報源の取得をまだ作っていないので、情報源は空にしている。
// 確認用のデータ（src/sources/fixture.ts）を選ぶのもこの層で、選ぶだけでデータは持たない
// （docs/adr/0004-fixture-data-for-acceptance.md）。

import type { TodayNewsDeps } from "@/services/today-news";
import type { XPostDeps } from "@/services/x-posts";
import { fixedClock, systemClock } from "@/ports/clock";
import { fetchHttpClient, fixtureHttpClient, withTimeout } from "@/ports/http";
import { FIXTURE_HTTP_RESPONSES, FIXTURE_ITEMS, FIXTURE_NOW } from "@/sources/fixture";
import { staticSource } from "@/sources/source";

/** X の oEmbed への 1 回の要求の時間切れ（ミリ秒）。画面の表示が oEmbed を待つのは、おおむねこの時間まで。 */
export const X_OEMBED_TIMEOUT_MS = 5000;

/** 確認用のデータを選ぶ環境変数の名前と値。ブラウザへ渡さないので NEXT_PUBLIC_ を付けない。 */
export const FIXTURE_ENV_NAME = "AI_NEWS_FIXTURE";
export const FIXTURE_ENV_VALUE = "sample";

/** 判定に使う環境変数（既定は process.env。試験では値を直接渡す）。 */
export type RuntimeEnv = Readonly<Record<string, string | undefined>>;

/**
 * 確認用のデータを使うかを決める。AI_NEWS_FIXTURE が sample で、かつ NODE_ENV が production でないときだけ真。
 * 本番の起動（next start と next build の後の実行）で誤って効かないよう、NODE_ENV で絞る。
 *
 * NODE_ENV は 2 か所を見る。引数の env.NODE_ENV（実行時の値）と、直接の参照 process.env.NODE_ENV である。
 * 直接の参照は、next build がビルドの時点の値（本番の build では production）に置き換えて固定する。
 * 実行時の値だけを見ると、本番の build を NODE_ENV=development を付けて next start したときに効いてしまうため、
 * 両方が production でないことを条件にする。直接の参照は、置き換えが効くよう、この形のまま関数の中に書く。
 */
export function isFixtureMode(env: RuntimeEnv = process.env): boolean {
  return (
    env[FIXTURE_ENV_NAME] === FIXTURE_ENV_VALUE &&
    env.NODE_ENV !== "production" &&
    process.env.NODE_ENV !== "production"
  );
}

export function createRuntimeDeps(env: RuntimeEnv = process.env): TodayNewsDeps {
  if (isFixtureMode(env)) {
    return {
      sources: [staticSource("fixture", FIXTURE_ITEMS)],
      clock: fixedClock(FIXTURE_NOW),
    };
  }
  return {
    sources: [],
    clock: systemClock,
  };
}

/**
 * X の投稿の埋め込みの取得に使う依存。時間切れは X の埋め込みの依存だけに付ける（fetchHttpClient は変えない）。
 * 確認用のデータのときは、外部へ通信せずに決まった応答を返す fixtureHttpClient を使う。
 */
export function createXPostDeps(env: RuntimeEnv = process.env): XPostDeps {
  if (isFixtureMode(env)) {
    return { http: fixtureHttpClient(FIXTURE_HTTP_RESPONSES) };
  }
  return { http: withTimeout(fetchHttpClient, X_OEMBED_TIMEOUT_MS) };
}
