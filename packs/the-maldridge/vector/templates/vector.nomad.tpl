#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "system"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "vector" {
    count = 1

    network {
      mode = "bridge"
    }

    volume "dockersocket" {  # XXX: Volume to doc spec like we did in ara
      type      = "host"
      source    = "dockersocket"
      read_only = true
    }

    task "vector" {
      driver = "docker"

      config {
        image = "docker.io/timberio/vector:[[ dig "version" "0.45.0-alpine" .Args ]]"
        args  = ["-c", "/local/vector.yaml"]
      }

      resources [[ dig "resources" (dict) .Args | tohcl ]]

      volume_mount {
        volume      = "dockersocket"
        destination = "/var/run/docker.sock"
        read_only   = true
      }

      template {
        data = yamlencode({
          sources = {
            docker = {
              type = "docker_logs"
              exclude_containers = [
                "vector-",
                "nomad_init_",
              ]
            }
          }
          sinks = {
            vlogs = {
              type        = "elasticsearch"
              inputs      = ["docker"]
              endpoints   = [[ dig "elasticsearch" "endpoints" (list) .Args |tohcl ]]
              api_version = "v8"
              compression = "gzip"
              healthcheck = { enabled = false }
              query = {
                "_time_field" = "timestamp"
                "_stream_fields" = join(",", formatlist("label.com.hashicorp.nomad.%s", [
                  "namespace", "job_name", "task_group_name", "task_name", "alloc_id",
                ]))
                "_msg_field" = "message"
              }
            }
          }
        })
        destination = "local/vector.yaml"
      }
    }
  }
}
