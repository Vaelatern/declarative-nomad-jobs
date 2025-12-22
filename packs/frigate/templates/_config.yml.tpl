[[ define "frigate-config" ]]
version: 0.14

go2rtc:
  streams:
{{ range nomadVarList "[[ dig "var-root" "facility/cameras" .Args ]]/inventory" -}}
 {{ with nomadVar .Path -}}
 {{ if ne .disabled.Value "true" }}
  {{ $localGo2rtc := print "rtsp://127.0.0.1:" (env "NOMAD_PORT_go2rtc") -}}
  {{ $fullQualityFFMPEG := "#video=h264#audio=opus" -}}
  {{ $lowQualityFFMPEG := "#video=h264#audio=opus" -}}
  {{ $fullQualityURL := "NoneProvided" -}}
  {{ $lowQualityURL := "NoneProvided" }}
    {{ or .description "NO-NAME-SET" }}-high:
      - "{{ print $localGo2rtc "/" (or .description "NO-NAME-SET") "-high" }}"
    {{ or .description "NO-NAME-SET" }}-low:
      - "{{ print $localGo2rtc "/" (or .description "NO-NAME-SET") "-low" }}"
 {{ end -}}
 {{ end -}}
{{- end }}

mqtt:
  #host: {{ env "NOMAD_IP_mqtt" }}
  #port: {{ env "NOMAD_HOST_PORT_mqtt" }}
  host: 127.0.0.1
  port: 1883

detectors:
[[ if (dig "detectors" "coral" false .Args) ]]
  coral:
    type: edgetpu
    device: usb
[[ end ]]
[[ if (dig "detectors" "cpu" false .Args) ]]
  ov:
    type: openvino
    device: GPU
model:
  width: 300
  height: 300
  input_tensor: nhwc
  input_pixel_format: bgr
  path: /openvino-model/ssdlite_mobilenet_v2.xml
  labelmap_path: /openvino-model/coco_91cl_bkgr.txt
[[ end ]]

audio:
  enabled: True

database:
  path: /media/frigate/frigate.db

birdseye:
  restream: True
  quality: 8
  mode: continuous
  layout:
    max_cameras: 4

ffmpeg:
  hwaccel_args: preset-vaapi
  output_args:
    record: preset-record-generic-audio-copy
  retry_interval: 60

objects:
  track:
    - person
    - bicycle
    - car

record:
  enabled: True
  retain:
    days: 14
    mode: motion
  events:
    retain:
      default: 15
      objects:
        person: 31

snapshots:
  enabled: True
  retain:
    default: 31

cameras:
{{ range nomadVarList "[[ dig "var-root" "facility/cameras" .Args ]]/inventory" -}}
{{ with nomadVar .Path }}
{{ if ne .disabled.Value "true" }}
  {{ or .description "NO-NAME-SET" }}:
    detect:
      enabled: True
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:{{ env "NOMAD_PORT_go2rtc" }}/{{ or .description "NO-NAME-SET" }}-high
          roles:
            - record
        - path: rtsp://127.0.0.1:{{ env "NOMAD_PORT_go2rtc" }}/{{ or .description "NO-NAME-SET" }}-low
          roles:
            {{ if ne .audio.Value "false" }}- audio{{ end }}
            - detect
    {{ if eq .audio.Value "false" }}audio:
      enabled: False{{ end }}
{{ end -}}
{{ end -}}
{{- end }}

auth:
  enabled: False
[[ end ]]
