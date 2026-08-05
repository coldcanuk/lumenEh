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

# Opt-in without DESTDIR: only run the desktop-shortcut target path via DESKTOP_SHORTCUT
# against a throwaway "system" install is not required; do-desktop-shortcut uses HOME only.
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

# --- 4) Grok Imagine instructions and icon source path ---
IMAGINE="$ROOT/assets/icons/GROK_IMAGINE_ICON.md"
ICON_SRC="$ROOT/assets/icons/lumeneh.png"
[[ -f "$IMAGINE" ]] || fail "missing $IMAGINE"
[[ -f "$ICON_SRC" ]] || fail "missing icon source $ICON_SRC"
grep -q 'assets/icons/lumeneh.png' "$IMAGINE" || fail "Imagine instructions must name assets/icons/lumeneh.png"
grep -qi 'icon\|markdown\|256' "$IMAGINE" || fail "Imagine instructions lack subject/size guidance"
# Makefile must install from that source path
grep -q 'assets/icons/lumeneh.png' "$ROOT/Makefile" || fail "Makefile does not reference assets/icons/lumeneh.png"

pass "Grok Imagine instructions and icon source path match install"

echo "All install launcher checks passed."
