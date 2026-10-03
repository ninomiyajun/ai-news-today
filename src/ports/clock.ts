// 現在時刻の入口。現在時刻は、この層の Clock からだけ得る（ARCHITECTURE.md の不変条件）。
// 試験では fixedClock で決まった時刻に差し替える。

export type Clock = {
  now: () => Date;
};

export const systemClock: Clock = {
  now: () => new Date(),
};

export function fixedClock(iso: string): Clock {
  const fixed = new Date(iso);
  if (Number.isNaN(fixed.getTime())) {
    throw new Error(`fixedClock: 日時として解釈できません: ${iso}`);
  }
  return { now: () => new Date(fixed.getTime()) };
}
