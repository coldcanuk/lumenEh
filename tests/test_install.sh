#!/usr/bin/env bash
# Drive the real make install / uninstall paths for launcher + icon + Desktop opt-in.
# Failures exit non-zero; safe to run without root via DESTDIR and a fake HOME.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f config.mk ]]; then
  echo "config.mk missing; run ./configure first" >&2
  exit 1
fi

# Ensure binary exists (install depends on it).
if [[ ! -x ./lumeneh ]]; then
  make -s all
fi

SCRATCH="${TEST_SCRATCH:-${TMPDIR:-/tmp}/lumeneh-test-install-$$}"
mkdir -p "$SCRATCH"
DEST="$SCRATCH/dest"
FAKEHOME="$SCRATCH/fakehome"
DESKTOP_DIR="$FAKEHOME/Desktop"
mkdir -p "$DEST" "$DESKTOP_DIR"

PREFIX="/usr"
APP_DESKTOP="$DEST$PREFIX/share/applications/lumeneh.desktop"
ICON_PATH="$DEST$PREFIX/share/icons/hicolor/256x256/apps/lumeneh.png"
BIN_PATH="$DEST$PREFIX/bin/lumeneh"
PERSONAL="$DESKTOP_DIR/lumeneh.desktop"

cleanup() {
  rm -rf "$SCRATCH"
}
# Keep scratch when TEST_KEEP=1 (verification harness captures elsewhere).
if [[ "${TEST_KEEP:-0}" != "1" ]]; then
  trap cleanup EXIT
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

# --- 1) Packaging-style DESTDIR install: apps + icon, no personal Desktop ---
rm -rf "$DEST"/*
mkdir -p "$DEST"
HOME="$FAKEHOME" make install DESTDIR="$DEST" PREFIX="$PREFIX" \
  bindir="$PREFIX/bin" \
  datadir="$PREFIX/share" \
  applicationsdir="$PREFIX/share/applications" \
  iconsdir="$PREFIX/share/icons/hicolor/256x256/apps"

[[ -x "$BIN_PATH" ]] || fail "binary not installed at $BIN_PATH"
[[ -f "$APP_DESKTOP" ]] || fail "desktop entry missing: $APP_DESKTOP"
[[ -f "$ICON_PATH" ]] || fail "icon missing: $ICON_PATH"
[[ ! -e "$PERSONAL" ]] || fail "DESTDIR install must not create personal Desktop shortcut"

# Desktop file identity
grep -q '^Type=Application$' "$APP_DESKTOP" || fail "Type=Application missing"
grep -q '^Exec=lumeneh' "$APP_DESKTOP" || fail "Exec=lumeneh missing"
grep -q '^Icon=lumeneh$' "$APP_DESKTOP" || fail "Icon=lumeneh missing (got: $(grep ^Icon= "$APP_DESKTOP" || true))"
grep -q 'markdown' "$APP_DESKTOP" || fail "markdown mime/keywords missing"
# Must not rely solely on stock theme icon name as the install story
if grep -q '^Icon=accessories-text-editor$' "$APP_DESKTOP"; then
  fail "Icon still points only at stock accessories-text-editor"
fi

# Icon asset must be PNG and non-empty
[[ -s "$ICON_PATH" ]] || fail "installed icon empty"
file "$ICON_PATH" | grep -qi 'PNG\|PNG image' || {
  # file(1) may say "PNG image data"
  python3 -c "import sys; d=open(sys.argv[1],'rb').read(8); sys.exit(0 if d[:8]==b'\\x89PNG\\r\\n\\x1a\\n' else 1)" "$ICON_PATH" \
    || fail "installed icon is not a PNG"
}

pass "DESTDIR install places binary, .desktop, and project icon"

# --- 2) Uninstall removes desktop + icon ---
HOME="$FAKEHOME" make uninstall DESTDIR="$DEST" PREFIX="$PREFIX" \
  bindir="$PREFIX/bin" \
  datadir="$PREFIX/share" \
  applicationsdir="$PREFIX/share/applications" \
  iconsdir="$PREFIX/share/icons/hicolor/256x256/apps"

[[ ! -e "$BIN_PATH" ]] || fail "binary still present after uninstall"
[[ ! -e "$APP_DESKTOP" ]] || fail ".desktop still present after uninstall"
[[ ! -e "$ICON_PATH" ]] || fail "icon still present after uninstall"

pass "uninstall removes binary, .desktop, and icon"

# --- 3a) Opt-in personal Desktop shortcut (no DESTDIR) ---
# Re-install system files into DEST only to keep prefix clean; personal shortcut
# is exercised with empty DESTDIR and fake HOME.
rm -rf "$DEST"/*
# System install with DESTDIR again (no personal)
HOME="$FAKEHOME" make install DESTDIR="$DEST" PREFIX="$PREFIX" \
  bindir="$PREFIX/bin" datadir="$PREFIX/share" \
  applicationsdir="$PREFIX/share/applications" \
  iconsdir="$PREFIX/share/icons/hicolor/256x256/apps" >/dev/null
[[ ! -e "$PERSONAL" ]] || fail "unexpected personal shortcut after DESTDIR reinstall"

# Opt-in without DESTDIR: real do-desktop-shortcut target (non-sudo HOME).
rm -f "$PERSONAL"
HOME="$FAKEHOME" make do-desktop-shortcut DESKTOP_SHORTCUT=1 DESTDIR=
[[ -f "$PERSONAL" ]] || fail "DESKTOP_SHORTCUT opt-in did not create $PERSONAL"
grep -q '^Type=Application$' "$PERSONAL" || fail "personal shortcut missing Type=Application"
grep -q '^Exec=lumeneh' "$PERSONAL" || fail "personal shortcut missing Exec=lumeneh"
grep -q '^Icon=lumeneh$' "$PERSONAL" || fail "personal shortcut missing Icon=lumeneh"

pass "opt-in DESKTOP_SHORTCUT creates personal Desktop launcher"

# --- 3b) Default DESTDIR packaging never touches Desktop ---
rm -f "$PERSONAL"
HOME="$FAKEHOME" make install DESTDIR="$DEST" PREFIX="$PREFIX" \
  bindir="$PREFIX/bin" datadir="$PREFIX/share" \
  applicationsdir="$PREFIX/share/applications" \
  iconsdir="$PREFIX/share/icons/hicolor/256x256/apps" \
  DESKTOP_SHORTCUT=1 >/dev/null
# Even with DESKTOP_SHORTCUT=1, DESTDIR must refuse personal shortcut
[[ ! -e "$PERSONAL" ]] || fail "DESTDIR + DESKTOP_SHORTCUT=1 must not create personal Desktop file"

pass "DESTDIR install never places personal Desktop shortcut (even if DESKTOP_SHORTCUT=1)"

# --- 3c) sudo path: HOME=/root + SUDO_USER → invoking user's Desktop, not root's ---
HELPER="$ROOT/scripts/resolve_desktop.sh"
[[ -x "$HELPER" || -f "$HELPER" ]] || fail "missing $HELPER"
chmod +x "$HELPER"

# Non-root: SUDO_USER alone must not redirect (no elevated install).
got_home="$(HOME=/root SUDO_USER=chuck bash "$HELPER" target-home)"
[[ "$got_home" == "/root" ]] || fail "non-root should use HOME=/root, got $got_home"

# EUID 0 (user namespace): SUDO_USER home via getent.
if command -v unshare >/dev/null 2>&1 && unshare -r true 2>/dev/null; then
  got_home="$(HOME=/root SUDO_USER=chuck unshare -r bash "$HELPER" target-home)"
  chuck_home="$(getent passwd chuck | cut -d: -f6)"
  [[ -n "$chuck_home" ]] || fail "getent passwd chuck failed"
  [[ "$got_home" == "$chuck_home" ]] || fail "root+SUDO_USER=chuck should resolve $chuck_home, got $got_home"
  pass "resolve_desktop target-home uses getent under EUID 0 + SUDO_USER"

  # Full make install/uninstall path with shadowed getent → fake user home (no real Desktop pollution).
  SUDO_HOME="$SCRATCH/sudo_user_home"
  ROOT_HOME="$SCRATCH/root_home"
  mkdir -p "$SUDO_HOME/Desktop" "$ROOT_HOME/Desktop" "$SCRATCH/bin"
  cat >"$SCRATCH/bin/getent" <<'GETENT'
#!/usr/bin/env bash
# Shadow getent for install tests: map SUDO_USER=testuser to FAKE_SUDO_HOME.
if [[ "${1:-}" == passwd && "${2:-}" == testuser ]]; then
  printf 'testuser:x:1001:1001::%s:/bin/bash\n' "${FAKE_SUDO_HOME:?}"
  exit 0
fi
exec /usr/bin/getent "$@"
GETENT
  chmod +x "$SCRATCH/bin/getent"

  rm -f "$SUDO_HOME/Desktop/lumeneh.desktop" "$ROOT_HOME/Desktop/lumeneh.desktop"
  # Drive the real make target under fake root with HOME=/root and SUDO_USER=testuser.
  FAKE_SUDO_HOME="$SUDO_HOME" PATH="$SCRATCH/bin:$PATH" HOME="$ROOT_HOME" SUDO_USER=testuser \
    unshare -r make -C "$ROOT" do-desktop-shortcut DESTDIR= \
    >"$SCRATCH/sudo-desktop-install.log" 2>&1 || {
      cat "$SCRATCH/sudo-desktop-install.log" >&2
      fail "make do-desktop-shortcut under unshare -r failed"
    }

  [[ -f "$SUDO_HOME/Desktop/lumeneh.desktop" ]] \
    || fail "sudo-style install did not create $SUDO_HOME/Desktop/lumeneh.desktop"
  [[ ! -e "$ROOT_HOME/Desktop/lumeneh.desktop" ]] \
    || fail "sudo-style install incorrectly wrote root Desktop shortcut"
  grep -q '^Icon=lumeneh$' "$SUDO_HOME/Desktop/lumeneh.desktop" \
    || fail "sudo-style personal shortcut missing Icon=lumeneh"

  pass "HOME=/root SUDO_USER=testuser install lands on invoking-user Desktop"

  # Uninstall via real make target: point system paths at empty scratch so we only
  # exercise personal-shortcut removal (same SUDO_USER resolution as install).
  FAKE_SUDO_HOME="$SUDO_HOME" PATH="$SCRATCH/bin:$PATH" HOME="$ROOT_HOME" SUDO_USER=testuser \
    unshare -r make -C "$ROOT" uninstall DESTDIR= \
    bindir="$SCRATCH/empty-prefix/bin" \
    applicationsdir="$SCRATCH/empty-prefix/share/applications" \
    iconsdir="$SCRATCH/empty-prefix/share/icons/hicolor/256x256/apps" \
    >"$SCRATCH/sudo-desktop-uninstall.log" 2>&1 || {
      cat "$SCRATCH/sudo-desktop-uninstall.log" >&2
      fail "make uninstall under unshare -r failed"
    }
  [[ ! -e "$SUDO_HOME/Desktop/lumeneh.desktop" ]] \
    || fail "sudo-style uninstall left $SUDO_HOME/Desktop/lumeneh.desktop"
  [[ ! -e "$ROOT_HOME/Desktop/lumeneh.desktop" ]] \
    || fail "unexpected root Desktop shortcut after uninstall"

  pass "sudo-style uninstall removes SUDO_USER Desktop shortcut"
else
  echo "SKIP: unshare -r unavailable; SUDO_USER euid0 install path not exercised end-to-end" >&2
  # Still assert helper encodes the root+SUDO_USER getent branch (static structure).
  grep -q 'SUDO_USER' "$HELPER" || fail "helper missing SUDO_USER handling"
  grep -q 'getent passwd' "$HELPER" || fail "helper missing getent passwd"
fi

# --- 4) Grok Imagine instructions and icon source path ---
IMAGINE="$ROOT/assets/icons/GROK_IMAGINE_ICON.md"
ICON_SRC="$ROOT/assets/icons/lumeneh.png"
[[ -f "$IMAGINE" ]] || fail "missing $IMAGINE"
[[ -f "$ICON_SRC" ]] || fail "missing icon source $ICON_SRC"
grep -q 'assets/icons/lumeneh.png' "$IMAGINE" || fail "Imagine instructions must name assets/icons/lumeneh.png"
grep -qi 'icon\|markdown\|256' "$IMAGINE" || fail "Imagine instructions lack subject/size guidance"
# Makefile must install from that source path
grep -q 'assets/icons/lumeneh.png' "$ROOT/Makefile" || fail "Makefile does not reference assets/icons/lumeneh.png"
grep -q 'resolve_desktop.sh' "$ROOT/Makefile" || fail "Makefile must call resolve_desktop.sh for Desktop shortcut"

pass "Grok Imagine instructions and icon source path match install"

echo "All install launcher checks passed."
