#!/usr/bin/env bash
# Domænevagt: ét RDAP-opslag pr. domæne.
#   404               -> ledigt: send "køb nu" (hver time, indtil planen slås fra)
#   "pending delete"  -> stille
#   registreret inden for 65 min -> send "taget" (én kørsel ser det, da planen er hver time)
#   ellers            -> stille (stadig registreret af den gamle ejer)
# Exit != 0 kun når selve opslaget fejler, så kortet lander i "Fejlet".
set -uo pipefail

rdap_base() {
  case "${1##*.}" in
    com|net) echo "https://rdap.verisign.com/${1##*.}/v1" ;;
    org)     echo "https://rdap.publicinterestregistry.org/rdap" ;;
    *)       echo "https://rdap.org" ;;
  esac
}

notify() { # title body url
  # Billedet skal ikke have CLI'en på forhånd: npx henter den, hvis node findes.
  if command -v agent-share >/dev/null 2>&1; then
    agent-share send --title "$1" --body "$2" ${3:+--url "$3"}
  elif command -v npx >/dev/null 2>&1; then
    npx -y @agentics-live/agent-share send --title "$1" --body "$2" ${3:+--url "$3"}
  else
    echo "hverken agent-share eller npx på runneren — beskeden blev IKKE sendt: $1" >&2
    return 1
  fi
}

[ $# -gt 0 ] || { echo "brug: $0 domæne..." >&2; exit 2; }
rc=0
now=$(date -u +%s)
for d in "$@"; do
  body=$(curl -sS -L --max-time 20 -w '\n%{http_code}' "$(rdap_base "$d")/domain/$d") || { echo "$d: opslag fejlede"; rc=1; continue; }
  code=${body##*$'\n'}; json=$(printf '%s' "${body%$'\n'*}" | tr -d '\n\t\r' | sed 's/" *: */":/g; s/, *"/,"/g; s/, *{/,{/g')
  case "$code" in
    404)
      echo "$d: LEDIGT"
      notify "$d er ledigt — køb nu" "RDAP svarer 404 for $d. Køb det i Cloudflare Registrar." \
        "https://dash.cloudflare.com/?to=/:account/domains/register/$d" || rc=1 ;;
    200)
      if grep -qi '"pending delete"' <<<"$json"; then
        echo "$d: pending delete"
      else
        reg=$(grep -o '"eventAction":"registration","eventDate":"[^"]*"' <<<"$json" | head -1 | sed 's/.*"eventDate":"\([^"]*\)"/\1/')
        regs=$(date -u -d "$reg" +%s 2>/dev/null || echo 0)
        registrar=$(grep -o '"fn",{},"text","[^"]*"' <<<"$json" | head -1 | cut -d'"' -f6)
        echo "$d: registreret $reg (${registrar:-ukendt registrar})"
        if [ "$regs" -gt 0 ] && [ $((now - regs)) -lt 3900 ]; then
          notify "$d blev taget" "$d blev registreret $reg hos ${registrar:-ukendt registrar}." "" || rc=1
        fi
      fi ;;
    *) echo "$d: uventet RDAP-svar $code"; rc=1 ;;
  esac
done
exit $rc
