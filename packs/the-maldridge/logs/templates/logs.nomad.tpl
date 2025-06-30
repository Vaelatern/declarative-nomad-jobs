#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "service"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "vmlogs" {
    count = 1

    network {
      mode = "bridge"
      port "http" { to = 9428 }
      port "syslog" { static = 514 }
    }

    service {
      name     = "logs"
      port     = "http"
      provider = "nomad"
      tags     = [[ getarg "tags" .Args ]]
    }

    volume "vmlogs_data" { # XXX: Update the volume to be from the config file
      type      = "host"
      source    = "vmlogs_data"
      read_only = "false"
    }

    task "vmlogs" {
      driver = "docker"

      config {
        image = "docker.io/victoriametrics/victoria-logs:[[ dig "version" "v1.15.0-victorialogs" .Args ]]"
        args = [
          "-storageDataPath=/data",
          "-syslog.listenAddr.tcp=:514",
          "-syslog.listenAddr.udp=:514",
        ]
      }

      volume_mount {
        volume      = "vmlogs_data"
        destination = "/data"
      }
    }
  }
}
