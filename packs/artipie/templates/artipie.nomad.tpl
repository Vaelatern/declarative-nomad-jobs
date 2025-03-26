job [[ getarg "jobname" .Args ]] {
        type = "service"
        datacenters = [[ getarg "datacenters" .Args ]]

        group "artipie" {
                network {
                        port "http" {
                                to = 8080
                        }
                        port "api-docs" {
                                to = 8086
                        }
                }

                service {
                        provider = "nomad"
                        port = "http"
                        tags = [[ dig "tags" "primary" (list) .Args ]]
                }

                task "artipie" {
                        driver = "docker"
                        config {
                                image = "artipie/artipie:[[ dig "version" "artipie" "latest" .Args ]]"
                                ports = ["http", "api-docs"]
                        }

                        resources [[ getarg "resources" .Args ]]
                }
        }
}
