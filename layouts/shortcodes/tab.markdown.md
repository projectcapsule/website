{{- /* Markdown rendition of Docsy's tab shortcode. The header becomes a bold
     label; the body is a fenced code block (Docsy's default) unless the tab or
     its tabpane sets text=true, in which case it is emitted as Markdown. */ -}}
{{- $header := "" -}}
{{- if and (not .IsNamedParams) (.Get 0) -}}
  {{- $header = .Get 0 -}}
{{- else -}}
  {{- $header = .Get "header" | default (printf "Tab %v" .Ordinal) -}}
{{- end -}}
{{- $label := trim (replaceRE "\\*+" "" $header) " " -}}
{{- $text := .Get "text" -}}
{{- $lang := .Get "lang" -}}
{{- with .Parent -}}
  {{- if not $text }}{{ $text = .Get "text" }}{{ end -}}
  {{- if not $lang }}{{ $lang = .Get "lang" }}{{ end -}}
  {{- if .Get "langEqualsHeader" }}{{ $lang = $label }}{{ end -}}
{{- end -}}
{{- $body := trim .Inner "\r\n" -}}

**{{ $label }}**
{{ if $body }}
{{ if $text }}{{ $body }}{{ else }}```{{ $lang }}
{{ $body }}
```{{ end }}
{{ end }}
