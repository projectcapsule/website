import type { Config, Context } from "@netlify/edge-functions";

/**
 * Serves the Markdown rendition of a page. Hugo publishes it as `index.md`
 * next to every `index.html` (output format "markdown" in
 * config/_default/hugo.yaml); this function makes it reachable in the two
 * ways AI agents expect:
 *
 *  1. The ".md URL" convention: `/docs/overview.md` -> `/docs/overview/index.md`.
 *  2. Content negotiation: `GET /docs/overview/` with `Accept: text/markdown`
 *     -> `/docs/overview/index.md`. Claude Code, Cursor and the AFDocs checker
 *     behind CLOMonitor's agent readiness section send that header.
 *
 * Netlify serves `.md` files as `text/markdown; charset=UTF-8`. Every other
 * request is bypassed (`undefined`) and served as usual.
 */
export default async (request: Request, _context: Context) => {
  if (request.method !== "GET" && request.method !== "HEAD") return;

  const url = new URL(request.url);
  const path = url.pathname;

  if (path.endsWith(".md")) {
    if (path.endsWith("/index.md")) return;
    return new URL(`${path.slice(0, -".md".length)}/index.md`, url);
  }

  if (hasExtension(path)) return;
  if (!prefersMarkdown(request.headers.get("accept"))) return;

  return new URL(`${path.endsWith("/") ? path : `${path}/`}index.md`, url);
};

/** Paths such as `/docs/index.xml` or `/llms.txt` are files, not pages. */
function hasExtension(path: string): boolean {
  const last = path.slice(path.lastIndexOf("/") + 1);
  return /\.[a-z0-9]+$/i.test(last);
}

/**
 * True when `text/markdown` is listed explicitly in the Accept header and is
 * not outranked by `text/html` (or a wildcard that covers it). Browsers never
 * list `text/markdown`, so they always get HTML.
 */
export function prefersMarkdown(accept: string | null): boolean {
  if (!accept) return false;

  let markdown = 0;
  let html = 0;

  for (const entry of accept.split(",")) {
    const [rawType, ...params] = entry.trim().split(";");
    const type = rawType.trim().toLowerCase();
    const q = params
      .map((p) => p.trim().toLowerCase())
      .find((p) => p.startsWith("q="));
    const weight = q === undefined ? 1 : Number(q.slice(2));
    if (!Number.isFinite(weight) || weight <= 0) continue;

    if (type === "text/markdown") markdown = Math.max(markdown, weight);
    else if (type === "text/html" || type === "text/*" || type === "*/*") {
      html = Math.max(html, weight);
    }
  }

  return markdown > 0 && markdown >= html;
}

export const config: Config = {
  // Sections whose pages carry a Markdown rendition (outputs.page/section in
  // config/_default/hugo.yaml), plus any ".md" URL. Add new top-level content
  // sections here so their pages negotiate Markdown too.
  path: ["/*.md", "/docs/*", "/ecosystem/*", "/project/*", "/adopters/*", "/support/*"],
};
