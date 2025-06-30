path = "nomad/jobs/[[ getarg "jobname" .Args | unquote]]"
items {
[[ dig "primary_user" "human" .Args ]]_passwd = [[ dig "passwords" (dig "primary_user" "human" .Args) "" .Args ]]
_terraform_passwd = [[ dig "passwords" "terraform" "" .Args ]]
}
