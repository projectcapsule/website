{{- /*
  Markdown rendition of a regular page, published as index.md next to the
  page's index.html (output format "markdown" in config/_default/hugo.yaml).
  Agents reach it through the .md URL, the "Accept: text/markdown" header
  (netlify/edge-functions/markdown.ts) and the links in /llms.txt.
*/ -}}
{{- partial "markdown/header.md" . -}}
{{- with trim .RenderShortcodes "\r\n" }}
{{ . }}
{{- end }}

{{ partial "markdown/footer.md" . -}}
