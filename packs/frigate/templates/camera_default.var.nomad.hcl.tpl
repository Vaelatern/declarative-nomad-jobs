path = "[[ dig "var-root" "facility/cameras" .Args ]]/default"

items [[ dig "cameras" "default" (dict) .Args | tohcl ]]
