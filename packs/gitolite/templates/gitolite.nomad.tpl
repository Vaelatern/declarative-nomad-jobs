#!/usr/bin/env -S nomad job run
[[ $Args := .Args ]]
job [[ getarg "jobname" .Args ]] {
  type = "service"
  datacenters = [[ getarg "datacenters" .Args ]]

  group "gitolite" {
    network {
      port "ssh" {
        to = 22
      }
    }

    service {
      provider = "nomad"
      port = "ssh"
      tags = [[ dig "tags" (list) .Args | tohcl ]]
    }

    task "gitolite" {
      driver = "docker"
      config {
        image = "ghcr.io/vaelatern/docker-gitolite:[[ dig "version" "master" .Args ]]"
	volumes = [
		"${NOMAD_SECRETS_DIR}/keys:/etc/ssh/keys",
		"local/docker-entrypoint.d:/docker-entrypoint.d",
		"local/gitolite-local:/var/lib/gitolite/local",
	]
        ports = ["ssh"]
      }

      resources [[ dig "resources" (dict) .Args | tohcl ]]

      env {
      	GIT_USER = [[ dig "git" "user" "git" .Args | tohcl ]]
      	DEFAULT_BRANCH = [[ dig "git" "branch" "default" "trunk" .Args | tohcl ]]
      	SSH_KEY = [[ dig "git" "default-key" "key" "" .Args | tohcl ]]
      	SSH_KEY_NAME = [[ dig "git" "default-key" "name" "admin" .Args | tohcl ]]
      	GITOLITE_RC = [[ dig "git" "config" "" .Args | tohcl ]]
      }

      [[ range $key_type := (list "ecdsa" "ed25519" "rsa") ]]
      template {
      	destination = "${NOMAD_SECRETS_DIR}/ssh_host_[[ $key_type ]]_key.pub"
	data = <<-EOF
	  {{ if nomadVarExists "nomad/jobs/[[ getarg "jobname" $Args | unquote ]]/gitolite/gitolite/[[ $key_type ]]" -}}{{ with nomadVar "nomad/jobs/[[ getarg "jobname" $Args | unquote ]]/gitolite/gitolite/[[ $key_type ]]" }}{{ .key }}{{ end }}{{ end }}
	  EOF
      }
      [[ end ]]

      [[ range $item := (dig "template" (list) .Args) ]]
      template [[ $item | tohcl ]]
      [[ end ]]
    }
  }
}
