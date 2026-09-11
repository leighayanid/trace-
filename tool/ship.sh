#!/usr/bin/env bash
# From a Neon project to a release build, in one command.
#
#   bash tool/ship.sh
#
# 1. Logs in to Neon and finds the project, branch and database.
# 2. Reads the Auth and Data API URLs and writes config/neon.json.
# 3. Adds your trusted domain, if you give one.
# 4. Signs in for real (tool/neon_check.sh) with exactly what is being shipped.
# 5. Only after that succeeds: disables sign-ups and, with a trusted domain,
#    turns off "Allow Localhost".
# 6. Analyzes, tests, and builds the release app bundle — and installs a
#    release APK on a connected Android phone if you want to try it.
#
# Safe to re-run: each step checks before it changes, and nothing on the Neon
# side changes until you confirm. NEON_PROJECT_ID skips the project question.
#
# Needs Node (the Neon CLI runs through npx) and Flutter on PATH, and a project
# with the Data API and Managed Better Auth enabled — README, "Sync backend".
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG=config/neon.json
LOCAL_ORIGIN=http://localhost:3000

# Pinned: the JSON fields read below were checked against this version.
neon() { npx -y neon@4.16.0 --no-color --no-analytics "$@"; }

# Prints a dotted path from JSON on stdin; fails quietly if the input is not
# JSON (the CLI prints plain messages for "not configured") or the path is
# missing, so the caller's own message is the one you see.
json_get() {
  node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      let v;
      try { v = JSON.parse(s); } catch { process.exit(1); }
      for (const k of process.argv[1].split(".")) v = v == null ? v : v[k];
      if (v == null) process.exit(1);
      console.log(typeof v === "object" ? JSON.stringify(v) : v);
    });' "$1"
}

step() { printf '\n── %s\n' "$*"; }
die() { printf '\n✗ %s\n' "$*" >&2; exit 1; }
yes_no() { local a; read -rp "$1 " a; [[ $a == [yY]* ]]; }

command -v node >/dev/null || die "Node.js is needed to run the Neon CLI."
command -v flutter >/dev/null || die "Flutter is not on PATH."

# ── 1. Neon ───────────────────────────────────────────────────────────────────

step "Neon login"
# Not captured: on first use this opens the browser to sign in, and its prompt
# has to be visible.
neon me

step "Project"
PROJECT=${NEON_PROJECT_ID:-}
if [[ -z $PROJECT ]]; then
  mapfile -t projects < <(neon projects list -o json | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      const o = JSON.parse(s);
      for (const p of Array.isArray(o) ? o : (o.projects ?? []))
        console.log(`${p.id}\t${p.name}`);
    });')
  case ${#projects[@]} in
    0) die "No Neon projects on this account." ;;
    1) PROJECT=${projects[0]%%$'\t'*} ;;
    *)
      for i in "${!projects[@]}"; do
        printf '  %d) %s\n' $((i + 1)) "${projects[$i]#*$'\t'}"
      done
      read -rp "Which project? [1-${#projects[@]}] " pick
      [[ $pick =~ ^[0-9]+$ ]] && (( pick >= 1 && pick <= ${#projects[@]} )) ||
        die "Not a choice: $pick"
      PROJECT=${projects[$((pick - 1))]%%$'\t'*}
      ;;
  esac
fi
echo "project:  $PROJECT"

BRANCH=$(neon branches list --project-id "$PROJECT" -o json | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    const b = JSON.parse(s).find(b => b.default);
    if (!b) process.exit(1);
    console.log(b.id);
  });') || die "Could not find the project's default branch."
echo "branch:   $BRANCH (default)"

scope=(--project-id "$PROJECT" --branch "$BRANCH")

auth_status=$(neon neon-auth status "${scope[@]}" -o json) ||
  die "Could not read Neon Auth status (error above)."
AUTH_URL=$(json_get base_url <<<"$auth_status") ||
  die "Neon Auth is not enabled. Console → Data API → enable with Managed Better Auth."
DATABASE=$(json_get db_name <<<"$auth_status")
echo "database: $DATABASE"

data_api=$(neon data-api get "${scope[@]}" --database "$DATABASE" -o json) ||
  die "Could not read the Data API (error above). Console → Data API → Enable."
API_URL=$(json_get url <<<"$data_api") ||
  die "The Data API is not enabled. Console → Data API → Enable."

# ── 2. Config ─────────────────────────────────────────────────────────────────

step "Origin"
current=$LOCAL_ORIGIN
[[ -f $CONFIG ]] && current=$(json_get NEON_AUTH_ORIGIN <"$CONFIG" 2>/dev/null || echo "$LOCAL_ORIGIN")
echo "The app sends this as its Origin; Neon must trust it."
echo "A domain you own lets \"Allow Localhost\" be switched off, as Neon advises."
read -rp "Trusted domain, e.g. https://trace.example.com [$current]: " ORIGIN
ORIGIN=${ORIGIN:-$current}
ORIGIN=${ORIGIN%/}
[[ $ORIGIN =~ ^https?://[^/[:space:]]+$ ]] ||
  die "An origin is scheme and host only, like https://trace.example.com — got [$ORIGIN]"
[[ $ORIGIN == http://localhost* ]] && localhost=yes || localhost=no
[[ $localhost == no && $ORIGIN != https://* ]] && die "A trusted domain must use https."

mkdir -p config
AUTH_URL=$AUTH_URL API_URL=$API_URL ORIGIN=$ORIGIN node -e '
  const { AUTH_URL, API_URL, ORIGIN } = process.env;
  require("fs").writeFileSync(process.argv[1], JSON.stringify({
    NEON_AUTH_BASE_URL: AUTH_URL,
    NEON_DATA_API_URL: API_URL,
    NEON_AUTH_ORIGIN: ORIGIN,
  }, null, 2) + "\n");' "$CONFIG"
echo "wrote $CONFIG"
echo "  auth:   $AUTH_URL"
echo "  data:   $API_URL"
echo "  origin: $ORIGIN"

# ── 3. Lock down ──────────────────────────────────────────────────────────────

step "Neon settings"
echo "About to:"
[[ $localhost == no ]] && echo "  • trust $ORIGIN"
echo "  • sign in once with your account, to prove the settings work"
echo "  • then disable new sign-ups"
if [[ $localhost == no ]]; then
  echo "  • then turn off Allow Localhost"
else
  echo "  • keep Allow Localhost on (the app's origin is localhost)"
fi
yes_no "Proceed? [y/N]" || die "Stopped. $CONFIG is written; nothing on Neon changed."

if [[ $localhost == no ]]; then
  if neon neon-auth domain list "${scope[@]}" -o json |
    ORIGIN=$ORIGIN node -e '
      let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
        const o = JSON.parse(s);
        const list = Array.isArray(o) ? o : (o.domains ?? []);
        process.exit(list.some(d => (d.domain ?? d) === process.env.ORIGIN) ? 0 : 1);
      });'; then
    echo "already trusted: $ORIGIN"
  else
    neon neon-auth domain add "$ORIGIN" "${scope[@]}"
  fi
else
  # A localhost origin only works while localhost is allowed; a previous run
  # may have switched it off.
  neon neon-auth domain allow-localhost enable "${scope[@]}"
fi

step "Sign-in check"
echo "Answer y to 'Create the account' only if you have never signed up."
NEON_AUTH_BASE_URL=$AUTH_URL NEON_DATA_API_URL=$API_URL NEON_AUTH_ORIGIN=$ORIGIN \
  bash tool/neon_check.sh ||
  die "Sign-in failed, so sign-ups and localhost were left as they were."

step "Disabling sign-ups"
neon neon-auth config email-password update --disable-sign-up "${scope[@]}" >/dev/null
echo "new sign-ups: off"

if [[ $localhost == no ]]; then
  step "Turning off Allow Localhost"
  neon neon-auth domain allow-localhost disable "${scope[@]}"
fi

# ── 4. Build ──────────────────────────────────────────────────────────────────

step "Analyze and test"
flutter analyze
flutter test

step "Release build"
[[ -f android/key.properties ]] || cat <<'EOF'
⚠ android/key.properties is missing, so this build is signed with the debug
  key. Fine for your own phone; the Play Console will reject it. See README,
  "Releasing".
EOF
flutter build appbundle --release --dart-define-from-file="$CONFIG"

phone=$(flutter devices --machine 2>/dev/null | node -e '
  let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
    const d = JSON.parse(s || "[]").find(d =>
      String(d.targetPlatform).startsWith("android") && !d.emulator);
    if (d) console.log(`${d.id}\t${d.name}`);
  });' || true)
if [[ -n $phone ]] && yes_no "Install a release build on ${phone#*$'\t'}? [y/N]"; then
  flutter build apk --release --dart-define-from-file="$CONFIG"
  flutter install --release -d "${phone%%$'\t'*}"
  echo "Installed. Open TRACE → More → Sync and sign in."
fi

step "Done"
echo "App bundle: build/app/outputs/bundle/release/app-release.aab"
