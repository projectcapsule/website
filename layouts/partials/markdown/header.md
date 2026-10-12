{{- /* Title, summary and the agent directive that open every Markdown page. */ -}}
# {{ .Title }}
{{ with .Description }}
> {{ trim (replaceRE "\\s+" " " .) " " }}
{{ end }}
> For the complete documentation index, see [llms.txt]({{ "llms.txt" | absURL }}).
> The HTML version of this page is at {{ (.OutputFormats.Get "HTML").Permalink }}.
