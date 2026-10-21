{{- /* Mirrors Docsy's page-meta-lastmod partial so the Markdown and HTML
     renditions carry the same text. */ -}}
{{- if and .GitInfo .Site.Params.github_repo -}}
---

{{ T "post_last_mod" }} {{ .Lastmod.Format .Site.Params.time_format_default }}: {{ .GitInfo.Subject }} ({{ .GitInfo.AbbreviatedHash }})
{{ end -}}
