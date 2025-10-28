#!/usr/bin/env -S nomad job run
job [[ getarg "jobname" .Args ]] {
	type = "service"
	datacenters = [[ getarg "datacenters" .Args ]]

	group "frigate" {
		count = 1

		network {
			mode = "bridge"
			port "http" {
				to = 8971
				static = 443
			}
			port "frigate_go2rtc" {
				static = 8554
			}
			port "go2rtc" {}
			port "go2rtc_api" {}
			port "mqtt" {
				to = 1883
			}
		}

		service {
			provider = "nomad"
			name = "frigate"
			port = "http"
			tags = ["http"]
		}

		service {
			provider = "nomad"
			name = "frigate-restream"
			port = "go2rtc"
		}

		service {
			provider = "nomad"
			name = "mqtt"
			port = "mqtt"
		}

		volume "frigate-data" [[ dig "persist" "frigate-data" (dict) .Args | tohcl ]]

		task "go2rtc" {
			driver = "docker"
			config {
				image	 = "alexxit/go2rtc:[[ dig "version" "go2rtc" "1.9.9-hardware" .Args ]]"
				ports	 = ["go2rtc"]
				volumes = ["go2rtc.yml:/config/go2rtc.yaml"]
				devices = [
					{ host_path = "/dev/dri/renderD128" },
				]
			}
			resources [[ dig "resources" "go2rtc" (dict) .Args | tohcl ]]
			template {
				destination = "go2rtc.yml"
				data = <<-EOF
[[ template "go2rtc-config" . ]]
EOF
			}
		}

		task "mosquitto" {
			driver = "docker"
			config {
				image = "eclipse-mosquitto:[[ dig "version" "mosquitto" "2.0.21" .Args ]]"
				ports = ["mqtt"]
			}
			resources [[ dig "resources" "mosquitto" (dict) .Args | tohcl ]]
		}

		task "frigate" {
			driver = "docker"
			config {
				image	 = "ghcr.io/blakeblackshear/frigate:[[ dig "version" "frigate" "0.14.1" .Args ]]"
				ports	 = ["http", "frigate_go2rtc"]
				volumes = ["config.yml:/config/config.yml",
						"tmpfs:/tmp"]
				# 4k resolution, plugged into frigate formula, *20 for num cameras
				shm_size	 = 2243952640
				privileged = true

				ulimit {
					nofile = "8192"
				}

				devices = [
					{ host_path = "/dev/dri/renderD128" },
					{ host_path = "/dev/bus/usb" }
				]
			}

			volume_mount {
				volume = "frigate-data"
				destination = "/media/frigate"
				read_only = false
			}

			resources [[ dig "resources" "frigate" (dict) .Args | tohcl ]]

			template {
				destination = "config.yml"
				data = <<-EOF
[[ template "frigate-config" . ]]
EOF
			}

		}

	}
}
