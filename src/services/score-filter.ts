// 処理の流れの層。画面の URL のクエリ min を点数の下限として解釈し、整形・選別の層の絞り込みの関数につなぐ。
// 画面の層は整形・選別の層を import できないので、この層が入口になる（ARCHITECTURE.md の「層と責務」）。

import { filterByMinScore } from "@/curation/score-filter";
import type { NewsItem } from "@/domain/news";

/** 点数の下限を指定する URL のクエリの名前（例: /?min=100）。 */
export const MIN_SCORE_QUERY_NAME = "min";

/**
 * クエリの値を点数の下限に変える。ASCII の数字だけの文字列で、安全な整数の範囲にあるときだけ、その数（0 以上の整数）を返す。
 * それ以外（無し、空、数でない、負、小数、前後の空白、同じ名前のクエリが複数ある配列など）は null（絞り込まない）を返す。
 */
export function parseMinScore(raw: string | readonly string[] | undefined): number | null {
  if (typeof raw !== "string") return null;
  if (!/^[0-9]+$/.test(raw)) return null;
  const n = Number(raw);
  return Number.isSafeInteger(n) ? n : null;
}

/** クエリの値を解釈し、点数がその下限以上の記事と、解釈した下限（絞り込まないときは null）を返す。 */
export function applyMinScore(
  items: readonly NewsItem[],
  raw: string | readonly string[] | undefined,
): { items: NewsItem[]; minScore: number | null } {
  const minScore = parseMinScore(raw);
  return { items: filterByMinScore(items, minScore), minScore };
}
