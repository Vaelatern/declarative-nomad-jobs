#!/usr/bin/env -S nomad job run
job "ara" {
  type        = "service"
  datacenters = ["MATRIX-CONTROL"]

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
      tags     = ["traefik.enable=true"]
    }


    volume "ara_data" {
      read_only = false
      source    = "ara_data"
      type      = "host"
    }


    task "ara" {
      driver = "docker"

      config {
        image = "docker.io/recordsansible/ara-api:v3.3.4"
      }

      env {
        ARA_ALLOWED_HOSTS = ["ara.matrix.michaelwashere.net"]
      }

      volume_mount {
        volume      = "ara_data"
        destination = "/opt/ara"
      }
    }
  }
}
