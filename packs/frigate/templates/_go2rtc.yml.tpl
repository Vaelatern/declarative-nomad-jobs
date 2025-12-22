[[ define "go2rtc-config" ]]
rtsp:
  listen: ":{{ env "NOMAD_PORT_go2rtc" }}"
api:
  listen: ":{{ env "NOMAD_PORT_go2rtc_api" }}"
streams:
{{ $default_user := "" -}}
{{ $default_pass := "" -}}
{{ if nomadVarExists "[[ dig "var-root" "facility/cameras" .Args ]]/default" -}}
 {{ with nomadVar "[[ dig "var-root" "facility/cameras" .Args ]]/default" -}}
  {{ $default_user = .username -}}
  {{ $default_pass = .password -}}
 {{ end -}}
{{ end -}}
{{ range nomadVarList "[[ dig "var-root" "facility/cameras" .Args ]]/inventory" -}}
 {{ with nomadVar .Path -}}
 {{ if ne .disabled.Value "true" }}
  {{ $user := "" -}}
  {{ $pass := "" -}}
  {{ if .Keys | contains "username" -}}
   {{ $user = .username -}}
  {{ else -}}
   {{ $user = $default_user -}}
  {{ end -}}
  {{ if .Keys | contains "password" -}}
   {{ $pass = .password -}}
  {{ else -}}
   {{ $pass = $default_pass -}}
  {{ end -}}
  {{ $fullQualityFFMPEG := "#video=h264#audio=opus" -}}
  {{ $lowQualityFFMPEG := "#video=h264#audio=opus" -}}
  {{ $fullQualityURL := "NoneProvided" -}}
  {{ $lowQualityURL := "NoneProvided" -}}
  {{ if eq .manufacturer.Value "reolink" -}}
   {{ if eq .quality.Value "4k" -}}
    {{ $fullQualityURL = print "rtsp://" $user ":" $pass "@" .ip "/h265Preview_01_main" -}}
   {{ else if eq .quality.Value "1080p" -}}
    {{ $fullQualityURL = print "rtmp://" .ip "/bcs/channel0_ext.bcs?channel=0&stream=2&user=" $user "&password=" $pass -}}
   {{ end -}}
   {{ $lowQualityURL = print "http://" .ip "/flv?port=1935&app=bcs&stream=channel0_ext.bcs&user=" $user "&password=" $pass -}}
  {{ else if eq .manufacturer.Value "amcrest" -}}
   {{ $fullQualityURL = print "rtsp://" $user ":" $pass "@" .ip ":554/cam/realmonitor?channel=1&subtype=0" -}}
   {{ $lowQualityURL = print "rtsp://" $user ":" $pass "@" .ip ":554/cam/realmonitor?channel=1&subtype=1" -}}
   {{ $fullQualityFFMPEG = "#preset-rtsp-restream" -}}
   {{ $lowQualityFFMPEG = "" -}}
  {{ else if eq .manufacturer.Value "annke" -}}
  {{ else if eq .manufacturer.Value "axis" -}}
   {{/* Later give us a profile0 and profile1 override in the variable config since these are custom terms */}}
   {{ $fullQualityURL = print "rtsp://" $user ":" $pass "@" .ip ":554/onvif-media/media.amp?profile=profile0" -}}
   {{ $lowQualityURL = print "rtsp://" $user ":" $pass "@" .ip ":554/onvif-media/media.amp?profile=profile1" -}}
  {{- end }}
  {{ or .description "NO-NAME-SET" }}-high:
    - "{{ $fullQualityURL }}"
    - "ffmpeg:{{ or .description "NO-NAME-SET" }}-high{{ $fullQualityFFMPEG }}"
  {{ or .description "NO-NAME-SET" }}-low:
    - "{{ $lowQualityURL }}"
      {{- if eq $lowQualityFFMPEG "" }}
      {{- else }}
    - "ffmpeg:{{ or .description "NO-NAME-SET" }}-low{{ $lowQualityFFMPEG }}"
      {{ end }}
 {{ end -}}
 {{ end -}}
{{- end }}
[[ end ]]
