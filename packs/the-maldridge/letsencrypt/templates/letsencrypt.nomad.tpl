#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "batch"
  datacenters = [[ getarg "datacenters" .Args ]]

  periodic {
    crons = [[ getarg "crons" .Args ]]
  }

  group "terraform" {
    count = 1

    network { mode = "bridge" }

    task "terraform" {
      driver = "docker"

      config {
        image = [[ getarg "image" .Args ]]
      }

      identity { env = true }

      env {
        TF_HTTP_USERNAME="[[ dig "tf_username" "_terraform" .Args ]]"
        NOMAD_ADDR="unix://${NOMAD_SECRETS_DIR}/api.sock"
      }

      template { # XXX: Add the variable file to template this out
        data = <<EOT
{{ with nomadVar "nomad/jobs/cert-renew" }}
TF_HTTP_PASSWORD="{{ .terraform_password }}"
NAMECHEAP_API_USER="{{ .namecheap_api_user }}"
NAMECHEAP_API_KEY="{{ .namecheap_api_key }}"
{{ end }}
EOT
        destination = "${NOMAD_SECRETS_DIR}/env"
        env = true
      }
    }
  }
}
