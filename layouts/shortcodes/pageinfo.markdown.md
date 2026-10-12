{{- /* Markdown rendition of Docsy's pageinfo shortcode: a blockquote. See
     alert.markdown.md for why paragraph wrappers are stripped. */ -}}
{{- $body := trim .Inner " \n\r\t" -}}
{{- $body = replaceRE "</p>\\s*<p>" "\n\n" $body -}}
{{- $body = replaceRE "</?p>" "" $body }}
{{ $body | replaceRE "(?m)^" "> " }}
