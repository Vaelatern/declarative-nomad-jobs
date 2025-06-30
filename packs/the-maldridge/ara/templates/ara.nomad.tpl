#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "service"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "ara" {
    count = 1

    network {
      mode = "bridge"
      port "http" { to = 8000 }
    }

    service {
      name     = "ara"
      port     = "http"
      provider = "nomad"
      tags     = [[ getarg "tags" .Args ]]
    }

    [[ if (dig "persist" "volume" false .Args) ]]
    volume "ara_data" [[ dig "persist" "volume" (dict) .Args | tohcl ]]
    [[ end ]]

    task "ara" {
      driver = "docker"

      config {
        image = "docker.io/recordsansible/ara-api:[[ dig "version" "latest" .Args ]]"
      }

      env {
        ARA_ALLOWED_HOSTS = [[ getarg "allowed_hosts" .Args ]]
      }

      volume_mount {
        volume      = "ara_data"
        destination = "/opt/ara"
      }
    }
  }
}
