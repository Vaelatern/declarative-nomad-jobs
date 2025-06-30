#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "system"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "traefik" {
    network {
      mode = "bridge"
      port "http" { static = 80 }
      port "https" { static = 443 }
      port "metrics" { static = 8080 }
    }

    service {
      port     = "http"
      provider = "nomad"
      tags = [[ getarg "tags" .Args ]]
    }

    task "traefik" {
      driver = "docker"

      identity {
        env         = true
        change_mode = "restart"
      }

      config {
        image = "traefik:[[ dig "version" "latest" .Args ]]"

        args = [[ getarg "args" .Args ]]
      }

      template {
        data = yamlencode([[ getarg "config" .Args ]])
        destination = "local/config.yaml"
      }

      template {
        data = <<EOT
{{- with nomadVar "nomad/jobs/proxy" -}}
{{ .certificate }}
{{- end }}
EOT
        destination = "secrets/cert.pem"
      }

      template {
        data = <<EOT
{{- with nomadVar "nomad/jobs/proxy" -}}
{{ .key }}
{{- end }}
EOT
        destination = "secrets/cert.key"
      }
    }
  }
}
