#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "service"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "terrastate" {
    count = 1

    network {
      mode = "bridge"
      port "http" { to = 8080 }
    }

    service {
      name     = "terrastate"
      port     = "http"
      provider = "nomad"
      tags     = [[ getarg "tags" .Args ]]
    }

    [[ if (dig "persist" "volume" false .Args) ]]
    volume "terrastate_data" [[ dig "persist" "volume" (dict) .Args | tohcl ]]
    [[ end ]]

    task "terrastate" {
      driver = "docker"

      config {
        image = "ghcr.io/the-maldridge/terrastate:[[ getarg "version" .Args | unquote ]]"
        init  = true
	[[ if (dig "persist" "localvolume" "" .Args) ]]
	volumes = [
		"[[ dig "persist" "localvolume" "/tmp/terrastate" .Args ]]:/data"
	]
	[[ end ]]
      }

      env {
        TS_AUTH          = "htpasswd"
        TS_BITCASK_PATH  = "/data"
        TS_HTGROUP_FILE  = "/secrets/.htgroup"
        TS_HTPASSWD_FILE = "/secrets/.htpasswd"
        TS_STORE         = "bitcask"
      }

      [[ if (dig "persist" "volume" false .Args) ]]
      volume_mount {
        volume      = "terrastate_data"
        destination = "/data"
        read_only   = false
      }
      [[ end ]]

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/[[ getarg "jobname" .Args | unquote ]]" }}
[[ dig "primary_user" "human" .Args ]]:{{ .[[ dig "primary_user" "human" .Args ]]_passwd }}
_terraform:{{ .terraform_passwd }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/.htpasswd"
      }

      template {
        data        = <<EOF
terrastate-tls: [[ getarg "primary_user" .Args ]] _terraform
terrastate-routeros: [[ getarg "primary_user" .Args ]]
terrastate-nomad: [[ getarg "primary_user" .Args ]]
EOF
        destination = "${NOMAD_SECRETS_DIR}/.htgroup"
      }
    }
  }
}
