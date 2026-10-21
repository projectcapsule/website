{{- /* Markdown rendition of Docsy's alert shortcode: a blockquote with the
     title in bold. Hugo hands {{% %}} shortcodes their inner content already
     rendered to HTML, so the paragraph wrappers are stripped to keep the
     blockquote readable as Markdown; inline tags (code, links) stay as is. */ -}}
{{- $body := trim .Inner " \n\r\t" -}}
{{- $body = replaceRE "</p>\\s*<p>" "\n\n" $body -}}
{{- $body = replaceRE "</?p>" "" $body }}
> {{ with .Get "title" }}**{{ . }}**{{ end }}
>
{{ $body | replaceRE "(?m)^" "> " }}
