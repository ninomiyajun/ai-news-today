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

/**
 * HttpClient を包み、get が timeoutMs ミリ秒のうちに決まらなければ例外で失敗させる。
 * 時間切れの後も元の要求は中断されない（呼び出し側が待たなくなるだけ）。
 */
export function withTimeout(client: HttpClient, timeoutMs: number): HttpClient {
  return {
    get: (url) => {
      let timer: ReturnType<typeof setTimeout> | undefined;
      const timeout = new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error(`HTTP の要求が ${timeoutMs} ミリ秒で時間切れになりました: ${url}`)), timeoutMs);
      });
      return Promise.race([client.get(url), timeout]).finally(() => clearTimeout(timer));
    },
  };
}

/** URL ごとに決まった応答を返す。登録の無い URL は 404 を返す。 */
export function fixtureHttpClient(responses: Record<string, HttpResponse>): HttpClient {
  return {
    get: async (url) => responses[url] ?? { status: 404, body: "" },
  };
}
