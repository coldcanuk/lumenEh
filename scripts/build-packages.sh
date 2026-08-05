#!/usr/bin/env bash
# Build lumenEh .deb and .rpm packages into releases/ using VERSION.
# Usage: scripts/build-packages.sh [VERSION]
# Honors DESTDIR-safe install (no personal Desktop shortcut).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
if [[ -z "${VERSION}" ]]; then
  echo "error: empty VERSION" >&2
  exit 1
fi

# Debian arch vs RPM arch
if command -v dpkg >/dev/null 2>&1; then
  DEB_ARCH="$(dpkg --print-architecture)"
else
  DEB_ARCH="$(uname -m)"
  case "${DEB_ARCH}" in
    x86_64) DEB_ARCH=amd64 ;;
    aarch64) DEB_ARCH=arm64 ;;
  esac
fi
RPM_ARCH="$(uname -m)"

MAINTAINER="${MAINTAINER:-coldcanuk <noreply@github.com>}"
URL="${URL:-https://github.com/coldcanuk/lumenEh}"
RELEASES="${ROOT}/releases"
WORKDIR="${ROOT}/.package-build"
PKG_REL="${PKG_REL:-1}"

rm -rf "${WORKDIR}"
mkdir -p "${RELEASES}" "${WORKDIR}"

echo "==> Building lumenEh ${VERSION} (deb=${DEB_ARCH}, rpm=${RPM_ARCH})"

# Machine-local config for install paths under /usr (packaging prefix).
if [[ ! -f config.mk ]] || ! grep -q 'iconsdir' config.mk 2>/dev/null; then
  ./configure --prefix=/usr
fi
make -j"$(nproc 2>/dev/null || echo 2)"

# ---------------------------------------------------------------------------
# .deb
# ---------------------------------------------------------------------------
DEB_NAME="lumeneh_${VERSION}_${DEB_ARCH}"
DEB_ROOT="${WORKDIR}/deb/${DEB_NAME}"
rm -rf "${DEB_ROOT}"
mkdir -p "${DEB_ROOT}/DEBIAN"

sed \
  -e "s/@VERSION@/${VERSION}/g" \
  -e "s/@ARCH@/${DEB_ARCH}/g" \
  -e "s/@MAINTAINER@/${MAINTAINER}/g" \
  packaging/deb/control.in > "${DEB_ROOT}/DEBIAN/control"

# Extra control metadata for a solid package.
{
  echo "Homepage: ${URL}"
  echo "Installed-Size: $(du -sk "${ROOT}/lumeneh" | awk '{print $1}')"
} >> "${DEB_ROOT}/DEBIAN/control"

make install DESTDIR="${DEB_ROOT}" PREFIX=/usr \
  bindir=/usr/bin datadir=/usr/share \
  applicationsdir=/usr/share/applications \
  iconsdir=/usr/share/icons/hicolor/256x256/apps \
  DESKTOP_SHORTCUT=0

# Optional: refresh icon cache / desktop db on target systems
cat > "${DEB_ROOT}/DEBIAN/postinst" <<'POST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
fi
exit 0
POST
chmod 755 "${DEB_ROOT}/DEBIAN/postinst"

dpkg-deb --build --root-owner-group "${DEB_ROOT}" "${RELEASES}/${DEB_NAME}.deb"
echo "    wrote ${RELEASES}/${DEB_NAME}.deb"

# ---------------------------------------------------------------------------
# .rpm (optional unless REQUIRE_RPM=1)
# ---------------------------------------------------------------------------
# Locate rpmbuild: PATH first, then optional user-local RPMTOOLS tree.
RPMBUILD_BIN=""
if command -v rpmbuild >/dev/null 2>&1; then
  RPMBUILD_BIN="$(command -v rpmbuild)"
elif [[ -n "${RPMTOOLS:-}" && -x "${RPMTOOLS}/usr/bin/rpmbuild" ]]; then
  RPMBUILD_BIN="${RPMTOOLS}/usr/bin/rpmbuild"
  export PATH="${RPMTOOLS}/usr/bin:${PATH}"
  if [[ -d "${RPMTOOLS}/usr/lib/x86_64-linux-gnu" ]]; then
    export LD_LIBRARY_PATH="${RPMTOOLS}/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
  fi
fi

RPM_BASENAME=""
if [[ -z "${RPMBUILD_BIN}" ]]; then
  msg="rpmbuild not found on PATH"
  if [[ "${REQUIRE_RPM:-0}" == "1" ]]; then
    echo "error: ${msg}; install rpm-build or set RPMTOOLS=… (REQUIRE_RPM=1)" >&2
    exit 1
  fi
  echo "warning: ${msg} — skipping .rpm (deb is ready)." >&2
  echo "         Install: sudo apt install rpm  # provides rpmbuild on Debian/Ubuntu" >&2
  echo "         Or: REQUIRE_RPM=1 to hard-fail; RPMTOOLS=/path/to/prefix for a local tree" >&2
  RPM_BASENAME="(skipped)"
else
  # User-local / non-system rpm installs need RPM_CONFIGDIR pointing at lib/rpm.
  if [[ -z "${RPM_CONFIGDIR:-}" ]]; then
    if [[ ! -f /usr/lib/rpm/rpmrc ]]; then
      for candidate in \
        "${RPMTOOLS:-}/usr/lib/rpm" \
        "$(dirname "${RPMBUILD_BIN}")/../lib/rpm"; do
        if [[ -f "${candidate}/rpmrc" ]]; then
          export RPM_CONFIGDIR="$(cd "${candidate}" && pwd)"
          break
        fi
      done
    fi
  fi
  if [[ ! -f /usr/lib/rpm/rpmrc ]] && [[ -z "${RPM_CONFIGDIR:-}" ]]; then
    if [[ "${REQUIRE_RPM:-0}" == "1" ]]; then
      echo "error: cannot find rpmrc (set RPM_CONFIGDIR to .../usr/lib/rpm)" >&2
      exit 1
    fi
    echo "warning: cannot find rpmrc — skipping .rpm (deb is ready)." >&2
    RPM_BASENAME="(skipped)"
  else
    RPM_TOP="${WORKDIR}/rpmbuild"
    RPM_STAGE="${WORKDIR}/rpm-root"
    rm -rf "${RPM_TOP}" "${RPM_STAGE}"
    mkdir -p \
      "${RPM_TOP}/BUILD" \
      "${RPM_TOP}/BUILDROOT" \
      "${RPM_TOP}/RPMS" \
      "${RPM_TOP}/SOURCES" \
      "${RPM_TOP}/SPECS" \
      "${RPM_TOP}/SRPMS" \
      "${RPM_STAGE}"

    make install DESTDIR="${RPM_STAGE}" PREFIX=/usr \
      bindir=/usr/bin datadir=/usr/share \
      applicationsdir=/usr/share/applications \
      iconsdir=/usr/share/icons/hicolor/256x256/apps \
      DESKTOP_SHORTCUT=0

    tar -C "${RPM_STAGE}" -czf "${RPM_TOP}/SOURCES/lumeneh-payload.tar.gz" .

    SPEC="${RPM_TOP}/SPECS/lumeneh-binary.spec"
    cat > "${SPEC}" <<EOF
Name:           lumeneh
Version:        ${VERSION}
Release:        ${PKG_REL}%{?dist}
Summary:        lumenEh native GTK3 markdown viewer
License:        GPL-3.0-or-later
URL:            ${URL}
Source0:        lumeneh-payload.tar.gz
BuildArch:      ${RPM_ARCH}
AutoReqProv:    yes

Requires:       gtk3

%description
lumenEh is a native GTK3 markdown viewer for local and remote (SSH) files.
Includes FreeDesktop application launcher entry and hicolor app icon.

%prep
# payload is a pre-staged filesystem tree (binary package)

%build
# nothing to compile

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
tar -C %{buildroot} -xzf %{SOURCE0}

%files
%{_bindir}/lumeneh
%{_datadir}/applications/lumeneh.desktop
%{_datadir}/icons/hicolor/256x256/apps/lumeneh.png

%changelog
* $(date '+%a %b %d %Y') ${MAINTAINER} - ${VERSION}-${PKG_REL}
- Package lumenEh ${VERSION} with application launcher and icon
EOF

    "${RPMBUILD_BIN}" \
      --define "_topdir ${RPM_TOP}" \
      --define "_build_id_links none" \
      -bb "${SPEC}"

    RPM_OUT="$(find "${RPM_TOP}/RPMS" -type f -name "lumeneh-${VERSION}-*.rpm" ! -name '*debug*' | head -n1)"
    if [[ -z "${RPM_OUT}" ]]; then
      echo "error: rpmbuild produced no lumeneh RPM" >&2
      find "${RPM_TOP}/RPMS" -type f || true
      exit 1
    fi
    RPM_BASENAME="$(basename "${RPM_OUT}")"
    cp -f "${RPM_OUT}" "${RELEASES}/${RPM_BASENAME}"
    echo "    wrote ${RELEASES}/${RPM_BASENAME}"
  fi
fi

# Manifest for humans / CI
{
  echo "version=${VERSION}"
  echo "deb=${DEB_NAME}.deb"
  echo "rpm=${RPM_BASENAME}"
  echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "commit=$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} > "${RELEASES}/MANIFEST-${VERSION}.txt"

echo "==> Packages ready in ${RELEASES}/"
ls -la "${RELEASES}/"*"${VERSION}"* 2>/dev/null || ls -la "${RELEASES}/"

# Cleanup build tree (keep releases/)
rm -rf "${WORKDIR}"
