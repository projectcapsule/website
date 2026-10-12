{{- /*
  Markdown rendition of a section page. Same as single.markdown.md plus the
  list of child pages that Docsy's section-index partial shows in HTML.
*/ -}}
{{- partial "markdown/header.md" . -}}
{{- with trim .RenderShortcodes "\r\n" }}
{{ . }}
{{- end }}
{{- $children := where .Pages.ByWeight ".Params.hide_summary" "!=" true }}
{{- if and $children (not .Params.no_list) }}

## Pages in this section
{{ range $children }}
- [{{ .Title }}]({{ with .OutputFormats.Get "markdown" }}{{ .Permalink }}{{ else }}{{ .Permalink }}{{ end }}){{ with .Description }}: {{ trim (replaceRE "\\s+" " " .) " " }}{{ end }}
{{- end }}
{{- end }}

{{ partial "markdown/footer.md" . -}}
