#!/usr/bin/env -S nomad job run
# Pack Notes:
#   - NOAMD_IP_acme is used to get the nomad port.
#     This is largely because the acme.sh container does not have the nomad CLI - NOMAD_UNIX_ADDR
#     Nor should it need it, there is a perfectly cromulent URL we can hit with curl
#     It is a hack. It should change. How? Help desired.
job "[[ getarg "jobname" .Args | unquote ]]" {
  type = "batch"
  namespace = [[ getarg "namespace" .Args ]]
  datacenters = [[ getarg "datacenters" .Args ]]
  periodic {
    crons = [[ dig "crons" (list (list (randInt 0 60) (randInt 0 24) "* * *" | join " ")) .Args | tohcl ]]
    prohibit_overlap = true
    [[ if (dig "tz" "" .Args) ]]time_zone = [[ dig "tz" "UTC" .Args | tohcl ]][[ end ]]
  }

  group "full-refresh-if-needed" {
    network {
        port "acme" {to = 80}
    }

    service {
      name = "acme"
      provider = [[ dig "http" "provider" "nomad" .Args | tohcl ]]
      port = "acme"
      tags = [[ dig "http" "tags" (list) .Args | tohcl ]]
    }

    task "execute-fetch" {
      restart {
        attempts = 0
        mode = "fail"
      }

      driver = "docker"
      config {
        image = [[ dig "image" "neilpang/acme.sh:3.0.8" .Args | tohcl ]]
        ports = ["acme"]
        args = ["${NOMAD_TASK_DIR}/renew-cert.sh"]
      }

      identity {
        env = true
      }

      ############################################################################################
      ############################################################################################
      ################> SCRIPTS <#################################################################
      ############################################################################################

      template {
        destination = "${NOMAD_TASK_DIR}/renew-cert.sh"
        perms = "755"
        data = <<-EOF
          exec 2>&1
          # Do this so we know if a variable needs changing
          ${NOMAD_TASK_DIR}/sync-account-down.sh
          # Create conf folder
          CONFPATH="${NOMAD_SECRETS_DIR}/conf"
          echo "USER_PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'" > "${CONFPATH}/account.conf"
          echo "LOG_FILE='${NOMAD_SECRETS_DIR}/conf/acme.sh.log'" >> "${CONFPATH}/account.conf"

          echo "****************************"
          echo "**> Sleeping to ensure <****"
          echo "**> reverse proxies are <***"
          echo "**> properly configured <***"
          echo "**> ...           <*********"
          sleep 30 # It sometimes takes a few seconds for our reverse proxy to start proxying this service
          # Yes it is racey. I don't know what to do about it. Low risk of it mattering.
          echo "**> ... Let's go. <*********"
          [[ range $site := dig "site" (list) .Args ]]
          echo "****************************"
          echo "******> [[ $site.domain ]] <******"
          "${NOMAD_TASK_DIR}"/fetch-cert.sh [[ $site.domain ]]
          [[- if $site.dns ]]
          "${NOMAD_TASK_DIR}"/fetch-dns-auth.sh [[ $site.dns ]]
          . "${NOMAD_SECRETS_DIR}"/dns-auth/[[ $site.dns ]].env
          [[- end ]]
          acme.sh --issue -d [[ $site.domain ]] \
            [[ default "" $site.extra_args ]] \
            --server [[ default $site.server "letsencrypt" ]] \
            [[ if $site.dns ]]--dns dns_[[ $site.dns ]][[ else ]]--standalone[[ end ]] \
            --reloadcmd "${NOMAD_TASK_DIR}/push-cert.sh [[ $site.domain ]]" \
            --config-home "${NOMAD_SECRETS_DIR}/conf" \
            --days [[ default 30 $site.days ]] [[ if $site.verbose ]] --log [[ end ]]
          [[- if $site.dns ]]
          . "${NOMAD_SECRETS_DIR}"/dns-auth/[[ $site.dns ]].unenv
          [[- end ]]
          [[ end ]]
          echo "****************************"
          echo "**> letsencrypt account <***"
          ${NOMAD_TASK_DIR}/sync-account-up.sh
          echo "**********> DONE <**********"
          echo "****************************"
          echo "****************************"
          echo "**> Sleeping so the user <**"
          echo "**> can log in to       <***"
          echo "**> investigate any issues <"
          echo "**> ...           <*********"
          sleep [[ mul 60 (dig "sleep_min" 15 .Args) ]] # Linger for [[ dig "sleep_min" 15 .Args ]] minutes so we can investigate
          echo "**> ... See you later. <****"
          echo "****************************"
          EOF
      }

      template {
        destination = "${NOMAD_TASK_DIR}/fetch-cert.sh"
        perms = "755"
        data = <<-EOF
          domain="$1"
          domain_for_path="$(echo $domain | tr '.' '_')"
          url="https://${NOMAD_IP_acme}:4646/v1/var/[[ dig "secrets" "cert_root" "letsencrypt" .Args ]]/${domain_for_path}"
          info_file="${NOMAD_SECRETS_DIR}/${domain}.read-response"
          tgt_dir="${NOMAD_SECRETS_DIR}/conf/${domain}_ecc"
          echo ">> Fetching certificate $domain from $url"
          curl --header "X-Nomad-Token: ${NOMAD_TOKEN}" -k "$url" > "$info_file"
          mkdir -p "$tgt_dir"
          jq -er '.Items .conf' < "$info_file" > "${tgt_dir}/${domain}.conf" || rm "${tgt_dir}/${domain}.conf"
          jq -er '.Items .cert' < "$info_file" > "${tgt_dir}/${domain}.cer" || rm "${tgt_dir}/${domain}.cer"
          jq -er '.Items .key' < "$info_file" > "${tgt_dir}/${domain}.key" || rm "${tgt_dir}/${domain}.key"
          jq -er '.Items .ca' < "$info_file" > "${tgt_dir}/ca.cer" || rm "${tgt_dir}/ca.cer"
          jq -er '.Items .fullchain' < "$info_file" > "${tgt_dir}/fullchain.cer" || rm "${tgt_dir}/fullchain.cer"
          jq -er '.ModifyIndex' < "$info_file" > "${tgt_dir}/ModifyIndex" || echo "0" > "${tgt_dir}/ModifyIndex"
          rm "$info_file"
          EOF
      }

      template {
        destination = "${NOMAD_TASK_DIR}/push-cert.sh"
        perms = "755"
        data = <<-EOF
          domain="$1"
          domain_for_path="$(echo $domain | tr '.' '_')"
          jq -n --rawfile fullchain "${NOMAD_SECRETS_DIR}/conf/${domain}_ecc/fullchain.cer" \
            --rawfile cert "${NOMAD_SECRETS_DIR}/conf/${domain}_ecc/${domain}.cer" \
            --rawfile key "${NOMAD_SECRETS_DIR}/conf/${domain}_ecc/${domain}.key" \
            --rawfile ca "${NOMAD_SECRETS_DIR}/conf/${domain}_ecc/ca.cer" \
            --rawfile conf "${NOMAD_SECRETS_DIR}/conf/${domain}_ecc/${domain}.conf" \
            --arg domain_for_path "$domain_for_path" \
            '{"Namespace": [[ getarg "namespace" .Args ]], "Path": "letsencrypt/$domain_for_path", "Items": $ARGS.named}' > ${NOMAD_SECRETS_DIR}/${domain}.write-request.json
          export modify_path="${NOMAD_SECRETS_DIR}/conf/${domain}_ecc/ModifyIndex"
          modify_index="$(cat $modify_path)"
          url="https://${NOMAD_IP_acme}:4646/v1/var/[[ dig "secrets" "cert_root" "letsencrypt" .Args ]]/${domain_for_path}?cas=${modify_index}"
          echo "Writing $domain details to: $url"
          curl --header "X-Nomad-Token: ${NOMAD_TOKEN}" -k -XPUT -d@"${NOMAD_SECRETS_DIR}/${domain}.write-request.json" "$url" > "${NOMAD_SECRETS_DIR}/${domain}.write-response"
          EOF
      }

      template {
        destination = "${NOMAD_TASK_DIR}/fetch-dns-auth.sh"
        perms = "755"
        data = <<-EOF
          provider="$1"
          ACC_PATH="${NOMAD_SECRETS_DIR}/dns-auth"
          mkdir -p "$ACC_PATH"
          cd "$ACC_PATH"
          url="https://${NOMAD_IP_acme}:4646/v1/var/[[ dig "secrets" "dns_auth_root" "auth/dns" .Args ]]/${provider}"
          info_file="${ACC_PATH}/${provider}.data"
          echo ">> Fetching "${provider} auth from $url"
          curl --header "X-Nomad-Token: ${NOMAD_TOKEN}" -k "$url" > "$info_file"
          "${NOMAD_TASK_DIR}"/fetch-dns-auth-$provider.sh "$ACC_PATH"
          rm "$info_file"
          EOF
      }

      #### XXX: TO MAKE NEW DNS PROVIDERS
      #### XXX : COPY THIS AND TAKE THE SAME ARG
      #### PROVIDER SHOULD HAVE THE SAME NAME AS IN ACME.SH
      template {
        destination = "${NOMAD_TASK_DIR}/fetch-dns-auth-freedns.sh"
        perms = "755"
        data = <<-EOF
          ACC_PATH="$1"
          info_file="${ACC_PATH}/freedns.data"
          printf "export FREEDNS_User='%s'\n"     "$(jq -er '.Items .user' < "$info_file")" >  "$ACC_PATH"/freedns.env || rm "$ACC_PATH"/freedns.env
          printf "export FREEDNS_Password='%s'\n" "$(jq -er '.Items .pass' < "$info_file")" >> "$ACC_PATH"/freedns.env || rm "$ACC_PATH"/freedns.env
          printf "unset FREEDNS_User FREEDNS_Password\n" > "$ACC_PATH"/freedns.unenv
          EOF
      }

      template {
        destination = "${NOMAD_TASK_DIR}/sync-account-down.sh"
        perms = "755"
        data = <<-EOF
          ACC_PATH="${NOMAD_SECRETS_DIR}/conf/ca/acme-v02.api.letsencrypt.org/directory"
          mkdir -p "$ACC_PATH"
          cd "$ACC_PATH"
          url="https://${NOMAD_IP_acme}:4646/v1/var/[[ dig "secrets" "account" "letsencrypt" .Args ]]"
          info_file="${NOMAD_SECRETS_DIR}/account.read-response"
          echo ">> Fetching account details from $url"
          curl --header "X-Nomad-Token: ${NOMAD_TOKEN}" -k "$url" > "$info_file"
          jq -er '.Items .key' < "$info_file" > "$ACC_PATH"/account.key || rm "$ACC_PATH"/account.key
          jq -er '.Items .json' < "$info_file" > "$ACC_PATH"/account.json || rm "$ACC_PATH"/account.json
          jq -er '.Items .conf' < "$info_file" > "$ACC_PATH"/ca.conf || rm "$ACC_PATH"/ca.conf
          jq -er '.ModifyIndex' < "$info_file" > "$ACC_PATH"/ModifyIndex || echo "0" > "$ACC_PATH"/ModifyIndex
          rm "$info_file"
          sha256sum * > ../shasums
          EOF
      }
      template {
        destination = "${NOMAD_TASK_DIR}/sync-account-up.sh"
        perms = "755"
        data = <<-EOF
          ACC_PATH="${NOMAD_SECRETS_DIR}/conf/ca/acme-v02.api.letsencrypt.org/directory"
          cd "$ACC_PATH"
          sha256sum -c ../shasums && echo "No change to account details" && exit 0
          jq -n --rawfile json "$ACC_PATH"/account.json \
            --rawfile conf "$ACC_PATH"/ca.conf \
            --rawfile key "$ACC_PATH"/account.key \
            '{"Namespace": [[ getarg "namespace" .Args ]], "Path": "letsencrypt", "Items": $ARGS.named}' > ${NOMAD_SECRETS_DIR}/account.write-request.json
          export modify_path="$ACC_PATH"/ModifyIndex
          modify_index="$(cat $modify_path)"
          url="https://${NOMAD_IP_acme}:4646/v1/var/[[ dig "secrets" "account" "letsencrypt" .Args ]]?cas=${modify_index}"
          echo "Writing to: $url"
          curl --header "X-Nomad-Token: ${NOMAD_TOKEN}" -k -XPUT -d@"${NOMAD_SECRETS_DIR}/account.write-request.json" "$url" > "${NOMAD_SECRETS_DIR}/account.write-response"
          EOF
      }
    }
  }
}
