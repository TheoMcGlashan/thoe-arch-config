#!/bin/sh

set -eu

PACCONF=".pacconf"

# Packages that must never be removed
PROTECTED_PKGS="
base
linux
linux-firmware
pacman
libc
systemd
"

usage() {
	echo "Usage: $0 info | sync " >&2
	echo 1
}

clean_pacconf_stream() {
  grep -v '^[[:space:]]*$' "$PACCONF" | grep -v '^[[:space:]]*#'
}

[ "$#" -eq 1 ] || usage

TMP_NEW="$(mktemp)"
TMP_OLD="$(mktemp)"

pacman -Qqe > "$TMP_NEW"

if [ -f "$PACCONF" ]; then
	clean_pacconf_stream > "$TMP_OLD"
else
	: > "$TMP_OLD"
fi


# Packages present in NEW but not in OLD
ADDED="$(grep -Fxv -f "$TMP_OLD" "$TMP_NEW" || true)"

# Packages present in OLD but not in NEW
REMOVED="$(grep -Fxv -f "$TMP_NEW" "$TMP_OLD" || true)"

case "$1" in

	info)
		echo "Packages installed locally not in .pacconf: $ADDED"
		echo "Packages in .pacconf not installed locally: $REMOVED"
	;;

	sync)
		pacman -Qqe > $PACCONF
		echo "Packagess added to .pacconf: $ADDED"
		echo 	
	;;
esac
