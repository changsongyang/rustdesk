{{- define "rustdesk-server.namespace" -}}
{{- if .Values.namespaceOverride }}
{{- .Values.namespaceOverride }}
{{- else }}
{{- .Release.Namespace | default "rustdesk" }}
{{- end }}
{{- end }}
