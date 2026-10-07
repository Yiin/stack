#!/usr/bin/env bash
# gen.sh <name> <aspect> <prompt>  -> <name>.raw (Gemini pro image)
set -uo pipefail
name="${1:?}"; ar="${2:?}"; prompt="${3:?}"
KEY=$(get-token GEMINI_API_KEY)
URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent?key=${KEY}"
resp=$(curl -s --max-time 300 "$URL" -H 'Content-Type: application/json' -d "$(jq -n --arg p "$prompt" --arg ar "$ar" '{contents:[{parts:[{text:$p}]}],generationConfig:{responseModalities:["TEXT","IMAGE"],imageConfig:{aspectRatio:$ar}}}')")
b64=$(printf '%s' "$resp" | jq -r '.candidates[0].content.parts[]? | select(.inlineData) | .inlineData.data' | head -1)
if [ -z "$b64" ] || [ "$b64" = null ]; then echo "FAIL $name: $(printf '%s' "$resp" | head -c 400)"; exit 1; fi
printf '%s' "$b64" | base64 -d > "$name.img" && echo "OK $name $(stat -c %s "$name.img")"
