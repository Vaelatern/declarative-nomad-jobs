#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
  type        = "sysbatch"
  datacenters = [[ getarg "datacenters" .Args ]]

  parameterized {
    payload       = "forbidden"
    meta_required = ["COMMIT", "ANSIBLE_PLAYBOOK"]
    meta_optional = []
  }

  group "ansible" {
    count = 1

    network { mode = "host" }

    task "ansible" {
      driver = "docker"
      config {
        image        = [[ getarg "image" .Args ]]
        network_mode = "host"
        privileged   = true
        command      = "/ansible/venv/bin/ansible-playbook"
        args = [
          "-D", "${NOMAD_META_ANSIBLE_PLAYBOOK}",
          "-c", "community.general.chroot",
          "-e", "ansible_host=/host",
          "--limit", "${node.unique.name}",
        ]
        volumes = ["/:/host"]
      }
    }
  }
}
