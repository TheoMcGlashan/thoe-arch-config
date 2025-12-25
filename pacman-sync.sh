#!/bin/sh

set -eu

PACCONF=".pacconf"

# Packages that must never be removed
PROTECTED_PKGS="
base
linux
linux-firmware
pacman
glibc
systemd
"

usage() {
  echo "Usage: $0 push | pull | clear" >&2
  exit 1
}

confirm() {
  printf "%s [y/N]: " "$1"
  read ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
}

is_protected() {
  printf "%s\n" "$PROTECTED_PKGS" | grep -qx "$1"
}

clean_pacconf_stream() {
  grep -v '^[[:space:]]*$' "$PACCONF" | grep -v '^[[:space:]]*#'
}

is_repo_pkg() {
  pacman -Si "$1" >/dev/null 2>&1
}

is_aur_pkg() {
  yay -Si "$1" >/dev/null 2>&1
}

[ "$#" -eq 1 ] || usage

case "$1" in
  push)
    pacman -Qe | cut -f 1 -d " " > "$PACCONF"
    echo "pacconf updated"
    ;;

  pull)
    [ -f "$PACCONF" ] || { echo "$PACCONF not found" >&2; exit 1; }
    command -v yay >/dev/null 2>&1 || {
      echo "Error: yay is required for AUR support" >&2
      exit 1
    }

    clean_pacconf_stream | while IFS= read -r pkg; do
      if is_repo_pkg "$pkg"; then
        pacman -S --needed "$pkg"
      elif is_aur_pkg "$pkg"; then
        yay -S --needed "$pkg"
      else
        echo "Warning: package not found in repos or AUR: $pkg" >&2
      fi
    done
    ;;

  clear)
    [ -f "$PACCONF" ] || { echo "$PACCONF not found" >&2; exit 1; }
    [ -s "$PACCONF" ] || { echo "$PACCONF is empty; refusing to proceed" >&2; exit 1; }

    command -v yay >/dev/null 2>&1 || {
      echo "Error: yay is required for AUR support" >&2
      exit 1
    }

    echo "Scanning for explicitly installed packages not in $PACCONF..."
    echo

    TO_REMOVE_REPO=""
    TO_REMOVE_AUR=""

    pacman -Qqe | while IFS= read -r pkg; do
      if is_protected "$pkg"; then
        continue
      fi

      if ! clean_pacconf_stream | grep -qx "$pkg"; then
        if is_aur_pkg "$pkg"; then
          echo "  would remove (AUR):  $pkg"
          TO_REMOVE_AUR="$TO_REMOVE_AUR $pkg"
        else
          echo "  would remove (repo): $pkg"
          TO_REMOVE_REPO="$TO_REMOVE_REPO $pkg"
        fi
      fi
    done

    if [ -z "$TO_REMOVE_REPO$TO_REMOVE_AUR" ]; then
      echo
      echo "System already matches $PACCONF; nothing to remove."
      exit 0
    fi

    echo
    echo "Dry run complete."
    confirm "Proceed with removing the listed packages?"

    for pkg in $TO_REMOVE_REPO; do
      pacman -Rns "$pkg"
    done

    for pkg in $TO_REMOVE_AUR; do
      yay -Rns "$pkg"
    done
    ;;

  *)
    usage
    ;;
esac
