// 外部への HTTP の入口。外部の情報源へのアクセスは、この層の HttpClient からだけ行う
// （ARCHITECTURE.md の不変条件）。試験では fixtureHttpClient で決まった応答に差し替える。

export type HttpResponse = {
  status: number;
  body: string;
};

export type HttpClient = {
  get: (url: string) => Promise<HttpResponse>;
};

export const fetchHttpClient: HttpClient = {
  get: async (url) => {
    const res = await fetch(url);
    return { status: res.status, body: await res.text() };
  },
};

/** URL ごとに決まった応答を返す。登録の無い URL は 404 を返す。 */
export function fixtureHttpClient(responses: Record<string, HttpResponse>): HttpClient {
  return {
    get: async (url) => responses[url] ?? { status: 404, body: "" },
  };
}
