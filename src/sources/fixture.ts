// 取得の層。確認用のデータ（決まった記事、基準の時刻、X の oEmbed の決まった応答）を、この 1 ファイルにまとめる。
// 受け入れ確認と、取得を作る前の画面の確認に使う（staticSource の説明と同じ用途）。データを選ぶのは
// src/composition/runtime.ts で、環境変数 AI_NEWS_FIXTURE=sample のときだけ選ぶ（docs/adr/0004-fixture-data-for-acceptance.md）。
//
// 記事に X の投稿の URL を含めない。含めると、画面に埋め込みが出て、ブラウザが外部のスクリプト（widgets.js）を
// 読みに行くためである（確認用のデータでは外部へ通信しない）。

import type { NewsItem } from "@/domain/news";
import type { HttpResponse } from "@/ports/http";

/** 確認用のデータの基準の時刻（fixedClock に渡す）。日本時間では 2026-10-07 の 12:00 に当たる。 */
export const FIXTURE_NOW = "2026-10-07T03:00:00Z";

/**
 * 確認用の記事。2 つの情報源から、点数と公開日時をばらけさせた 6 件を置く。
 * 画面に出るのは前の 4 件で、点数の高い順に 412、156、88、37 と並ぶ。
 * 公開日時は、どの「今日」の決め方（基準の時刻から遡る時間の幅、日本時間の暦日など）でも、表示する記事は範囲に入り、
 * 落とす記事は範囲から外れる時刻を選んだ。表示する 4 件は、日本時間の暦日の始まり（2026-10-06T15:00Z）より後で、
 * 基準の時刻より前にある。後の 2 件は選別で落ちる記事（日本時間でも 2 日前に公開されたもの、公開日時の分からないもの）で、
 * どちらも点数を最も高い側にしてあるので、選別が効かなければ一覧の先頭に出て気づける。
 */
export const FIXTURE_ITEMS: readonly NewsItem[] = [
  {
    id: "hn:fixture-1",
    title: "[確認用] 小さな言語モデルの推論を速くする手法",
    url: "https://example.com/fixture/hn-1",
    source: "hacker-news",
    score: 412,
    publishedAt: new Date("2026-10-07T01:00:00Z"),
  },
  {
    id: "hatena:fixture-1",
    title: "[確認用] 生成 AI の社内利用の指針を公開",
    url: "https://example.com/fixture/hatena-1",
    source: "hatena-bookmark",
    score: 156,
    publishedAt: new Date("2026-10-06T22:30:00Z"),
  },
  {
    id: "hn:fixture-2",
    title: "[確認用] 公開された重みのモデルの評価の比較",
    url: "https://example.com/fixture/hn-2",
    source: "hacker-news",
    score: 88,
    publishedAt: new Date("2026-10-06T16:00:00Z"),
  },
  {
    id: "hatena:fixture-2",
    title: "[確認用] 画像生成モデルの著作権の論点の整理",
    url: "https://example.com/fixture/hatena-2",
    source: "hatena-bookmark",
    score: 37,
    publishedAt: new Date("2026-10-07T02:30:00Z"),
  },
  {
    id: "hn:fixture-3",
    title: "[確認用] 2 日前の記事（表示されない）",
    url: "https://example.com/fixture/hn-3",
    source: "hacker-news",
    score: 999,
    publishedAt: new Date("2026-10-04T20:00:00Z"),
  },
  {
    id: "hatena:fixture-3",
    title: "[確認用] 公開日時の分からない記事（表示されない）",
    url: "https://example.com/fixture/hatena-3",
    source: "hatena-bookmark",
    score: 500,
    publishedAt: null,
  },
];

/**
 * X の oEmbed の要求に返す決まった応答（fixtureHttpClient に渡す表）。記事に X の投稿の URL が無いので空にしている。
 * 表に無い要求には、fixtureHttpClient が外へ出ずに 404 を返す。
 */
export const FIXTURE_HTTP_RESPONSES: Readonly<Record<string, HttpResponse>> = {};
