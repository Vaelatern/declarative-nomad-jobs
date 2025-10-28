#!/usr/bin/env -S nomad job run
job "[[ getarg "jobname" .Args | unquote ]]-controller" {
  type        = "service"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "controller" {
    task "controller" {
      driver = "docker"

      config {
        image = "registry.gitlab.com/rocketduck/csi-plugin-nfs:[[ dig "version" "1.1.0" .Args ]]"

        args = [
          "--type=controller",
          "--node-id=${attr.unique.hostname}",
          "--nfs-server=[[ dig "nfs" "server" "localhost" .Args ]]:[[ dig "nfs" "root" "/export" .Args ]]",
          "--mount-options=[[ dig "mount-options" "defaults" .Args ]]",
        ]

        network_mode = "host" # required so the mount works even after stopping the container

        privileged = true
      }

      csi_plugin {
        id        = "[[ dig "csi-name" "nfs" .Args ]]" # node & controller config needs to match
        type      = "controller"
        mount_dir = "/csi"
      }

      resources [[ dig "resources" "controller" (dict "cpu" 500 "memory" 256) .Args | tohcl ]]

    }
  }
}
