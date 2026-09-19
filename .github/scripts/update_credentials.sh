#!/usr/bin/env bash

set -euo pipefail

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

CREDENTIALS_FILE="$(pwd)/credentials.json"

log() { echo ":: $*" >&2; }
fail() { log "ERROR: $*"; exit 1; }

version_gt() {
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

aptoide_info() {
  feature="$1"
  response="$(curl -sSf "https://ws2-cache.aptoide.com/api/7/apps/search?query=crunchyroll&cdn=web&q=bXlDUFU9YXJtNjQtdjhhLGFybWVhYmktdjdhLGFybWVhYmkmbGVhbmJhY2s9MA&aab=1&limit=1&apk_required_features=${feature}")"

  vername="$(echo "$response" | jq -r '.datalist.list.[0].file.vername // empty')"
  vercode="$(echo "$response" | jq -r '.datalist.list.[0].file.vercode // empty')"
  url="$(echo "$response" | jq -r '.datalist.list.[0].file.path // empty')"

  [ -n "$vername" ] && [ -n "$vercode" ] && [ -n "$url" ] || fail "could not parse aptoide info for feature=$feature"

  echo "$vername $vercode $url"
}

extract_credentials() {
  apk_path="$1"

  output="$(curl -sSf https://raw.githubusercontent.com/crunchy-labs/crunchyroll-scripts/refs/heads/master/apk-credentials-extract.sh | bash -s -- "$apk_path" --info-stderr)"

  client_id="$(echo "$output" | grep -oP '(?<=^client id: ).+')"
  client_secret="$(echo "$output" | grep -oP '(?<=^client secret: ).+')"
  basic_auth="$(echo "$output" | grep -oP '(?<=basic auth credentials: ).+')"

  [ -n "$client_id" ] && [ -n "$client_secret" ] && [ -n "$basic_auth" ] || fail "could not extract credentials from $apk_path"

  echo "$client_id $client_secret $basic_auth"
}

github_output() {
  key="$1"
  value="$2"

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "${key}=${value}" >> "$GITHUB_OUTPUT"
  fi
  log "${key}=${value}"
}

update_profile() {
  profile="$1"
  vername="$2"
  vercode="$3"
  url="$4"

  cur_version="$(jq -r --arg k "$profile" '.[$k].version // "0"' "$CREDENTIALS_FILE")"
  cur_version_code="$(jq -r --arg k "$profile" '.[$k].version_code // "0"' "$CREDENTIALS_FILE")"

  if ! version_gt "$vername" "$cur_version" && [ "$vercode" = "$cur_version_code" ]; then
    log "$profile version unchanged: $vername ($vercode)"
    echo "false"
    return
  fi

  log "New $profile version detected: $vername (was: $cur_version)"
  log "Downloading $profile apk"
  curl -sSfL -o "$SCRATCH/$profile.apk" "$url"

  log "Extracting $profile credentials"
  creds="$(extract_credentials "$SCRATCH/$profile.apk")" || fail "could not extract $profile credentials"
  read -r client_id client_secret basic_auth <<< "$creds"

  log "Updating $CREDENTIALS_FILE"
  jq --arg k "$profile" --arg id "$client_id" --arg secret "$client_secret" \
     --arg auth "$basic_auth" --arg ver "$vername" --arg code "$vercode" \
     '.[$k] |= {client_id: $id, client_secret: $secret, basic_auth_token: $auth, version: $ver, version_code: $code}' \
     "$CREDENTIALS_FILE" > "$SCRATCH/credentials.json.tmp"
  mv "$SCRATCH/credentials.json.tmp" "$CREDENTIALS_FILE"

  echo "true"
}

# === main ===
[ -f "$CREDENTIALS_FILE" ] || fail "credentials file not found: $CREDENTIALS_FILE"

log "Fetching android_tv apk info"
info="$(aptoide_info "android.software.leanback")" || fail "could not fetch android_tv apk info"
read -r tv_vername tv_vercode tv_url <<< "$info"

log "Fetching android_phone apk info"
info="$(aptoide_info "android.hardware.faketouch")" || fail "could not fetch android_phone apk info"
read -r phone_vername phone_vercode phone_url <<< "$info"

android_tv_updated="$(update_profile "android_tv" "$tv_vername" "$tv_vercode" "$tv_url")"
android_phone_updated="$(update_profile "android_phone" "$phone_vername" "$phone_vercode" "$phone_url")"

if [ "$android_tv_updated" = "true" ] || [ "$android_phone_updated" = "true" ]; then
  changed="true"
else
  changed="false"
fi
github_output changed "$changed"
github_output android_tv_updated "$android_tv_updated"
github_output android_phone_updated "$android_phone_updated"
github_output android_tv_vername "$tv_vername"
github_output android_phone_vername "$phone_vername"

if [ "$changed" = "false" ]; then
  log "Nothing to update"
fi
