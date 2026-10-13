// 表示の部品のひな形。受け取った値を表示するだけで、処理の中身は入れていない。使い方は templates/module/README.md。

type Props = {
  /** 表示する文字 */
  text: string;
};

export function ExampleLabel({ text }: Props) {
  return <p>{text}</p>;
}
