#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "service"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "pxe" {
    count = [[ dig "count" "pxe" 1 .Args ]]

    network {
      mode = "host"
    }

    task "pxe" {
      driver = "docker"

      config {
        image        = "[[ dig "images" "pxe" "registry/netinst/pxe:latest" .Args ]]"
        force_pull   = true
        network_mode = "host"
        cap_add      = ["NET_ADMIN", "NET_RAW"]
      }
    }
  }

  [[ $port := dig "static_port" 8081 .Args ]]
  group "shoelaces" {
    count = [[ dig "count" "shoelaces" 1 .Args ]]
    network {
      mode = "bridge"
      port "http" { static = [[ $port ]] }
    }

    service {
      name     = "shoelaces"
      port     = "http"
      provider = "nomad"
      tags     = [[ getarg "tags" .Args ]]
    }

    task "shoelaces" {
      driver = "docker"

      config {
        image        = "[[ dig "images" "shoelaces" "registry/netinst/shoelaces:latest" .Args ]]"
        force_pull = true
        args       = ["-bind-addr=0.0.0.0:[[ $port ]]", "-base-url=${NOMAD_IP_http}:[[ $port ]]"]
      }
    }
  }
}
