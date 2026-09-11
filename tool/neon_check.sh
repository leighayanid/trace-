#!/usr/bin/env bash
# Checks that Neon Auth and the Data API behave the way NeonAuthClient expects.
#
#   bash tool/neon_check.sh
#
# Prompts for everything, so nothing sensitive lands in shell history. Prints
# status codes, header names and yes/no answers — never a token, because a
# session token is as good as the password.
set -euo pipefail

# Pasted URLs pick up stray quotes, brackets, spaces and CRs; curl rejects all
# of them as "malformed input". Strip them, and any trailing slash.
clean_url() { printf '%s' "$1" | tr -d '\r\n\t "<>'\' | sed 's:/*$::'; }
json_escape() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }
token_in() { sed -n 's/.*"token":"\([^"]*\)".*/\1/p' "$1" | head -1; }
header_in() { grep -i "^$1:" "$2" | head -1 | cut -d' ' -f2- | tr -d '\r' || true; }

read -rp 'Auth URL (ends in /neondb/auth): ' AUTH
read -rp 'Data API URL (ends in /neondb/rest/v1): ' API
read -rp 'Email: ' EMAIL
read -rsp 'Password: ' PASSWORD; echo
read -rp 'Create the account now? Only the first time. [y/N] ' NEW

AUTH=$(clean_url "$AUTH")
API=$(clean_url "$API")
case $AUTH in https://*/neondb/auth) ;; *) echo "Auth URL looks wrong: [$AUTH]"; exit 1 ;; esac
case $API in https://*/rest/v1) ;; *) echo "Data API URL looks wrong: [$API]"; exit 1 ;; esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

email=$(json_escape "$EMAIL")
password=$(json_escape "$PASSWORD")
if [[ $NEW == [yY]* ]]; then
  path=sign-up/email
  body="{\"email\":\"$email\",\"password\":\"$password\",\"name\":\"Leigh\"}"
else
  path=sign-in/email
  body="{\"email\":\"$email\",\"password\":\"$password\"}"
fi

# The body goes in on stdin so the password never appears in the process list.
auth_request() {
  curl -sS -o "$tmp/a_body" -D "$tmp/a_headers" -c "$tmp/jar" -w '%{http_code}' \
    -X POST "$AUTH/$path" -H 'Content-Type: application/json' "$@" \
    --data-binary @- <<<"$body"
}

echo
echo "── a) $path"
status=$(auth_request)
echo "status:              $status"
origin_needed=no
# Neon answers 400 MISSING_ORIGIN (or 403 for an untrusted one). Localhost is
# trusted by default while "Allow Localhost" is on.
if (( status >= 400 )) && grep -qi origin "$tmp/a_body"; then
  origin_needed=yes
  status=$(auth_request -H 'Origin: http://localhost:3000')
  echo "retried with Origin: $status"
fi
if (( status >= 400 )); then
  echo "error:               $(cat "$tmp/a_body")"
  exit 1
fi
session=$(header_in set-auth-token "$tmp/a_headers")
echo "Origin required:     $origin_needed"
echo "set-auth-token:      $([[ -n $session ]] && echo yes || echo no)"
echo "token in body:       $([[ -n $(token_in "$tmp/a_body") ]] && echo yes || echo no)"
echo "cookies set:         $(sed -n 's/^[Ss]et-[Cc]ookie: *\([^=]*\)=.*/\1/p' "$tmp/a_headers" | tr '\n' ' ')"
[[ -z $session ]] && session=$(token_in "$tmp/a_body")

echo
echo "── b) session → JWT"
status=$(curl -sS -o "$tmp/b_body" -w '%{http_code}' "$AUTH/token" \
  -H "Authorization: Bearer $session")
echo "with bearer header:  $status"
jwt=$(token_in "$tmp/b_body")
if [[ -z $jwt ]]; then
  # Tells a bearer-plugin problem apart from a broken session.
  status=$(curl -sS -o "$tmp/b_body" -w '%{http_code}' -b "$tmp/jar" "$AUTH/token")
  echo "with cookie instead: $status"
  jwt=$(token_in "$tmp/b_body")
  if [[ -z $jwt ]]; then
    echo "error:               $(cat "$tmp/b_body")"
    exit 1
  fi
fi
payload=$(printf '%s' "$jwt" | cut -d. -f2 | tr '_-' '/+')
while (( ${#payload} % 4 )); do payload+='='; done
claims=$(printf '%s' "$payload" | base64 -d 2>/dev/null || true)
echo "JWT received:        yes (${#jwt} chars)"
echo "role claim:          $(grep -o '"role":"[^"]*"' <<<"$claims" || echo none)"

echo
echo "── c) Data API"
status=$(curl -sS -o "$tmp/c_body" -w '%{http_code}' "$API/entries?select=id&limit=1" \
  -H "Authorization: Bearer $jwt")
echo "with JWT:            $status  $(cat "$tmp/c_body")"
status=$(curl -sS -o /dev/null -w '%{http_code}' "$API/entries?select=id&limit=1")
echo "without JWT:         $status  (should be refused)"
