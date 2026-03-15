#!/bin/zsh

curl 'https://api.tokenfactory.nebius.com/v1/chat/completions' \
    -X 'POST' \
    -H 'Content-Type: application/json' \
    -H 'Accept: */*' \
    -H "Authorization: Bearer $NEBIUS_API_KEY" \
    --data-binary '{"model":"nvidia/nemotron-3-super-120b-a12b","messages":[{"role":"system","content":"SYSTEM_PROMPT"}]}'
