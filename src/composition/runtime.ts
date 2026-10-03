// 実行時の依存を組み立てる層。本物の時計と情報源を選ぶのは、この層だけである。
// 試験では、この層を使わず、services に fixedClock と staticSource を直接渡す。
// P1 では、情報源の取得をまだ作っていないので、情報源は空にしている。

import type { TodayNewsDeps } from "@/services/today-news";
import { systemClock } from "@/ports/clock";

export function createRuntimeDeps(): TodayNewsDeps {
  return {
    sources: [],
    clock: systemClock,
  };
}
