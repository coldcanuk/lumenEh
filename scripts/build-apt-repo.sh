#!/usr/bin/env bash
# Build an APT repository tree from releases/*.deb into apt-repo/.
#
# After this tree is signed and published over HTTPS, users can:
#   sudo apt update && sudo apt install lumeneh
#
# Usage:
#   make packages                  # need a .deb first
#   scripts/build-apt-repo.sh      # build indexes (+ sign if possible)
#   scripts/sign-apt-repo.sh       # sign interactively if build could not
#
# Env:
#   GPG_KEY_ID       default: chuck@actvite.com
#   GPG_PASSPHRASE   optional; enables non-interactive signing
#   SKIP_SIGN=1      build only, never sign
#   CODENAME         default: stable

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(tr -d '[:space:]' < VERSION)"
GPG_KEY_ID="${GPG_KEY_ID:-chuck@actvite.com}"
CODENAME="${CODENAME:-stable}"
ORIGIN="${ORIGIN:-lumenEh}"
LABEL="${LABEL:-lumenEh}"
COMPONENT="main"
REPO_DIR="${ROOT}/apt-repo"
KEYRING_SRC="${ROOT}/packaging/apt/lumeneh-archive-keyring.gpg"
KEYRING_ASC="${ROOT}/packaging/apt/lumeneh-archive-keyring.asc"
SKIP_SIGN="${SKIP_SIGN:-0}"

DEB="$(ls -1 "${ROOT}/releases"/lumeneh_*_*.deb 2>/dev/null | sort -V | tail -n1 || true)"
if [[ -z "${DEB}" || ! -f "${DEB}" ]]; then
  echo "error: no .deb in releases/; run: make packages" >&2
  exit 1
fi
if [[ ! -f "${KEYRING_SRC}" || ! -f "${KEYRING_ASC}" ]]; then
  echo "error: missing public keyring under packaging/apt/" >&2
  exit 1
fi
for cmd in dpkg-scanpackages apt-ftparchive gzip; do
  command -v "${cmd}" >/dev/null 2>&1 || {
    echo "error: ${cmd} required" >&2
    exit 1
  }
done

ARCH="$(dpkg-deb -f "${DEB}" Architecture)"
PKG_NAME="$(basename "${DEB}")"

echo "==> Building APT repo for ${PKG_NAME} (suite=${CODENAME}, arch=${ARCH})"

rm -rf "${REPO_DIR}"
POOL_DIR="${REPO_DIR}/pool/${COMPONENT}/l/lumeneh"
DIST_BIN="${REPO_DIR}/dists/${CODENAME}/${COMPONENT}/binary-${ARCH}"
mkdir -p "${POOL_DIR}" "${DIST_BIN}" "${REPO_DIR}/keyring"

cp -f "${DEB}" "${POOL_DIR}/${PKG_NAME}"
cp -f "${KEYRING_SRC}" "${REPO_DIR}/keyring/lumeneh-archive-keyring.gpg"
cp -f "${KEYRING_ASC}" "${REPO_DIR}/keyring/lumeneh-archive-keyring.asc"

(
  cd "${REPO_DIR}"
  dpkg-scanpackages --arch "${ARCH}" "pool/${COMPONENT}" /dev/null \
    > "dists/${CODENAME}/${COMPONENT}/binary-${ARCH}/Packages"
  gzip -9c "dists/${CODENAME}/${COMPONENT}/binary-${ARCH}/Packages" \
    > "dists/${CODENAME}/${COMPONENT}/binary-${ARCH}/Packages.gz"
)

APT_CONF="${REPO_DIR}/.aptftp.conf"
cat > "${APT_CONF}" <<EOF
APT::FTPArchive::Release::Origin "${ORIGIN}";
APT::FTPArchive::Release::Label "${LABEL}";
APT::FTPArchive::Release::Suite "${CODENAME}";
APT::FTPArchive::Release::Codename "${CODENAME}";
APT::FTPArchive::Release::Architectures "${ARCH}";
APT::FTPArchive::Release::Components "${COMPONENT}";
APT::FTPArchive::Release::Description "lumenEh APT repository";
EOF

(
  cd "${REPO_DIR}"
  apt-ftparchive -c "${APT_CONF}" release "dists/${CODENAME}" \
    > "dists/${CODENAME}/Release"
)
rm -f "${APT_CONF}"

if ! grep -q '^Package: lumeneh$' "${DIST_BIN}/Packages"; then
  echo "error: Packages index missing Package: lumeneh" >&2
  exit 1
fi

echo "    wrote ${REPO_DIR}/ (unsigned indexes ready)"

sign_repo() {
  command -v gpg >/dev/null 2>&1 || return 1
  gpg --list-secret-keys "${GPG_KEY_ID}" >/dev/null 2>&1 || return 1

  local gpg_extra=()
  if [[ -n "${GPG_PASSPHRASE+x}" ]]; then
    gpg_extra+=(--pinentry-mode loopback --passphrase "${GPG_PASSPHRASE}")
  fi

  rm -f "${REPO_DIR}/dists/${CODENAME}/InRelease" \
        "${REPO_DIR}/dists/${CODENAME}/Release.gpg"

  if ! gpg --batch --yes "${gpg_extra[@]}" \
      --default-key "${GPG_KEY_ID}" \
      --clearsign -o "${REPO_DIR}/dists/${CODENAME}/InRelease" \
      "${REPO_DIR}/dists/${CODENAME}/Release" 2>/tmp/lumeneh-gpg-sign.err; then
    cat /tmp/lumeneh-gpg-sign.err >&2 || true
    return 1
  fi
  if ! gpg --batch --yes "${gpg_extra[@]}" \
      --default-key "${GPG_KEY_ID}" \
      -abs -o "${REPO_DIR}/dists/${CODENAME}/Release.gpg" \
      "${REPO_DIR}/dists/${CODENAME}/Release" 2>/tmp/lumeneh-gpg-sign.err; then
    cat /tmp/lumeneh-gpg-sign.err >&2 || true
    return 1
  fi
  gpg --verify "${REPO_DIR}/dists/${CODENAME}/InRelease" >/dev/null 2>&1
}

if [[ "${SKIP_SIGN}" == "1" ]]; then
  echo "    SKIP_SIGN=1 — not signing"
elif sign_repo; then
  echo "    signed dists/${CODENAME}/InRelease + Release.gpg"
else
  echo "    warning: could not sign (passphrase needed or no secret key)." >&2
  echo "    Run interactively:  scripts/sign-apt-repo.sh" >&2
  echo "    Or: GPG_PASSPHRASE='…' scripts/build-apt-repo.sh" >&2
fi

cat > "${REPO_DIR}/README.md" <<EOF
# lumenEh APT repository

Built from lumenEh **${VERSION}** (\`${PKG_NAME}\`).

## Publish

Host this entire directory over HTTPS so that:

- \`<BASE>/dists/${CODENAME}/InRelease\`
- \`<BASE>/pool/...\`
- \`<BASE>/keyring/lumeneh-archive-keyring.gpg\`

are reachable. Typical: GitHub Pages project site or a small VPS.

## End-user install

\`\`\`bash
curl -fsSL <BASE>/keyring/lumeneh-archive-keyring.gpg \\
  | sudo tee /usr/share/keyrings/lumeneh-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/lumeneh-archive-keyring.gpg] <BASE> ${CODENAME} ${COMPONENT}" \\
  | sudo tee /etc/apt/sources.list.d/lumeneh.list

sudo apt update
sudo apt install lumeneh
\`\`\`

Replace \`<BASE>\` with your published URL (no trailing slash), e.g.
\`https://coldcanuk.github.io/lumenEh-apt\`.
EOF

echo "==> APT repo ready under ${REPO_DIR}/"
echo "    Next: sign (if needed), publish over HTTPS, document <BASE> URL."
