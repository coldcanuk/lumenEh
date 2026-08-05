#!/usr/bin/env bash
# Resolve the personal Desktop location for lumenEh shortcut install/uninstall.
#
# When make install runs under sudo, $HOME is typically /root. In that case the
# personal shortcut must go to the *invoking* user's Desktop (SUDO_USER), not
# root's. Same resolution is used for uninstall so the file is not left behind.
#
# Commands:
#   target-home              Print home directory for the Desktop owner.
#   desktop-dir              Print that user's Desktop directory path.
#   install-shortcut SRC     Install SRC as Desktop/lumeneh.desktop.
#   remove-shortcut          Remove Desktop/lumeneh.desktop if present.

set -euo pipefail

cmd="${1:-}"

# Home of the user who should own the personal Desktop shortcut.
# Root + SUDO_USER → getent home for SUDO_USER; otherwise $HOME.
target_home() {
	local home=""
	if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != root ]; then
		home="$(getent passwd "${SUDO_USER}" | cut -d: -f6 || true)"
		if [ -n "${home}" ]; then
			printf '%s\n' "${home}"
			return 0
		fi
	fi
	printf '%s\n' "${HOME:-}"
}

# FreeDesktop Desktop directory for target_home (XDG_DESKTOP_DIR or ~/Desktop).
desktop_dir() {
	local uh desk
	uh="$(target_home)"
	desk=""
	if [ -n "${uh}" ] && [ -f "${uh}/.config/user-dirs.dirs" ]; then
		desk="$(sed -n 's/^XDG_DESKTOP_DIR="\(.*\)"/\1/p' "${uh}/.config/user-dirs.dirs" | head -n1)"
		# Expand $HOME inside the value against the target user's home.
		desk="$(HOME="${uh}" eval echo "${desk}")"
	fi
	if [ -z "${desk}" ] && [ -n "${uh}" ]; then
		desk="${uh}/Desktop"
	fi
	printf '%s\n' "${desk}"
}

install_shortcut() {
	local src="${1:?source .desktop path required}"
	local desk ug

	desk="$(desktop_dir)"
	if [ -z "${desk}" ]; then
		echo "warning: cannot resolve Desktop directory; skipping personal shortcut" >&2
		exit 0
	fi

	mkdir -p "${desk}"

	if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != root ]; then
		if ug="$(id -gn "${SUDO_USER}" 2>/dev/null)"; then
			# Prefer invoking-user ownership so root does not own their Desktop files.
			chown "${SUDO_USER}:${ug}" "${desk}" 2>/dev/null || true
			install -o "${SUDO_USER}" -g "${ug}" -Dm644 "${src}" "${desk}/lumeneh.desktop"
		else
			install -Dm644 "${src}" "${desk}/lumeneh.desktop"
		fi
	else
		install -Dm644 "${src}" "${desk}/lumeneh.desktop"
	fi
	echo "Installed personal Desktop shortcut: ${desk}/lumeneh.desktop"
}

remove_shortcut() {
	local desk
	desk="$(desktop_dir)"
	if [ -n "${desk}" ]; then
		rm -f "${desk}/lumeneh.desktop"
	fi
}

case "${cmd}" in
	target-home) target_home ;;
	desktop-dir) desktop_dir ;;
	install-shortcut)
		shift
		install_shortcut "${1:?source .desktop path required}"
		;;
	remove-shortcut) remove_shortcut ;;
	*)
		echo "usage: $0 target-home|desktop-dir|install-shortcut SRC|remove-shortcut" >&2
		exit 2
		;;
esac
