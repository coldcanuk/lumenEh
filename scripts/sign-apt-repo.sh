#!/usr/bin/env bash
# Interactively sign apt-repo/dists/<suite>/Release → InRelease + Release.gpg
# Run after scripts/build-apt-repo.sh if non-interactive signing failed.
#
# Usage:
#   scripts/sign-apt-repo.sh
#   GPG_KEY_ID=chuck@actvite.com scripts/sign-apt-repo.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="${ROOT}/apt-repo"
CODENAME="${CODENAME:-stable}"
GPG_KEY_ID="${GPG_KEY_ID:-chuck@actvite.com}"
RELEASE="${REPO_DIR}/dists/${CODENAME}/Release"

if [[ ! -f "${RELEASE}" ]]; then
  echo "error: missing ${RELEASE}; run scripts/build-apt-repo.sh first" >&2
  exit 1
fi
if ! gpg --list-secret-keys "${GPG_KEY_ID}" >/dev/null 2>&1; then
  echo "error: no secret key for ${GPG_KEY_ID}" >&2
  echo "import your private key from LastPass, then retry." >&2
  exit 1
fi

echo "Signing with ${GPG_KEY_ID} (pinentry may ask for passphrase)…"
rm -f "${REPO_DIR}/dists/${CODENAME}/InRelease" \
      "${REPO_DIR}/dists/${CODENAME}/Release.gpg"

gpg --default-key "${GPG_KEY_ID}" \
  --clearsign -o "${REPO_DIR}/dists/${CODENAME}/InRelease" \
  "${RELEASE}"

gpg --default-key "${GPG_KEY_ID}" \
  -abs -o "${REPO_DIR}/dists/${CODENAME}/Release.gpg" \
  "${RELEASE}"

gpg --verify "${REPO_DIR}/dists/${CODENAME}/InRelease"
echo "OK: signed ${REPO_DIR}/dists/${CODENAME}/InRelease"
