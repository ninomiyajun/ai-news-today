// 表示の部品の層。確認用のデータで表示していることを、画面の上に知らせる。判定はしない（受け取った値を出すだけ）。

/** 画面に出す文言。受け入れ確認と人が、確認用のデータの画面かどうかをこの文言で見分ける。 */
export const FIXTURE_NOTICE_TEXT = "確認用のデータで表示中";

type Props = {
  /** 確認用のデータで表示しているか（画面の層が組み立ての層の判定を受け取って渡す） */
  active: boolean;
};

export function FixtureNotice({ active }: Props) {
  if (!active) return null;
  return (
    <p
      role="status"
      style={{ margin: "0 0 1rem", padding: "0.5rem 0.75rem", border: "1px solid #b45309", background: "#fef3c7", color: "#78350f" }}
    >
      <strong>{FIXTURE_NOTICE_TEXT}</strong>（記事と時刻は決まった値で、外部へ通信しません）
    </p>
  );
}
