// 表示の部品の層。点数の下限で絞り込んでいることを知らせる。判定はしない（受け取った値を出すだけ）。

/**
 * 画面に出す文言。1 つの文字列として組み立てる。JSX で文字列と数を並べると、サーバーで描いた HTML では間に区切りの
 * コメントが入り、HTML の文字列の検索で文言が見つからなくなるためである。
 */
export function minScoreNoticeText(n: number): string {
  return `点数 ${n} 以上を表示中`;
}

type Props = {
  /** 点数の下限。絞り込んでいないときは null（画面の層が処理の流れの層の結果を受け取って渡す） */
  minScore: number | null;
};

export function MinScoreNotice({ minScore }: Props) {
  if (minScore === null) return null;
  return <p role="status">{minScoreNoticeText(minScore)}</p>;
}
