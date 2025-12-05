#!/usr/bin/env -S nomad acl policy apply -description "Permits adjusting letsencrypt variables and certs" -namespace [[ getarg "namespace" .Args ]] -job "[[ getarg "jobname" .Args | unquote ]]" -group "full-refresh-if-needed" "[[ getarg "jobname" .Args | unquote ]]-letsencrypt-cert"

namespace "default" {
  variables {
    # account
    path "[[ dig "secrets" "account" "letsencrypt" .Args ]]" {
      capabilities = ["read", "write"]
    }
    # site certs
    path "[[ dig "secrets" "cert_root" "letsencrypt" .Args ]]/*" {
      capabilities = ["read", "write"]
    }
    # DNS auth
    path "[[ dig "secrets" "dns_auth_root" "auth/dns" .Args ]]/*" {
      capabilities = ["read"]
    }
  }
}
