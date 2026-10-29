#!/usr/bin/env bash
# Installs Lattice Diamond for Linux into the image from whichever installer
# is in the directory given (gateware/docker/installer/ on the host), then
# points /opt/diamond at the installation.
#
#   install-diamond.sh DIR           install
#   install-diamond.sh --info DIR    only describe the installer
#
# Lattice has shipped Diamond for Linux as an .rpm (3.13 and earlier) and as a
# self-extracting .run (3.14). An .rpm is unpacked without running its
# scripts. A .run is identified by the packaging tool that built it and run
# unattended with that tool's options; if it is of a kind not recognised
# here, the script stops and prints what it found, for the options to be
# added below.

set -euo pipefail

info_only=0
if [ "${1:-}" = --info ]; then
  info_only=1
  shift
fi
src=${1:?usage: install-diamond.sh [--info] DIR}
prefix=/usr/local/diamond/install

shopt -s nullglob globstar
installers=("$src"/*.rpm "$src"/*.run)
if [ "${#installers[@]}" -ne 1 ]; then
  echo "Put exactly one Diamond for Linux installer (.run or .rpm) in gateware/docker/installer/;" >&2
  echo "found ${#installers[@]}." >&2
  exit 1
fi
installer=${installers[0]}
echo "Diamond installer: $(basename "$installer") ($(du -h "$installer" | cut -f1))"

# The packaging tool's name is in the first few MB of a .run: in the shell
# header of a makeself archive, or in the strings of an ELF installer.
head_has() { grep -a -q -i -e "$1" < <(head -c 64000000 "$installer"); }

kind=unknown
case "$installer" in
  *.rpm) kind=rpm ;;
  *.run)
    if head_has 'makeself'; then kind=makeself
    elif head_has 'InstallBuilder\|BitRock'; then kind=installbuilder
    elif head_has 'Qt Installer Framework\|QInstaller\|installerbase'; then kind=qtifw
    elif head_has 'install4j'; then kind=install4j
    fi ;;
esac
echo "Installer kind: $kind"

describe() {
  set +o pipefail
  echo "--- file(1) and first lines:"
  head -c 512 "$installer" | od -c | head -n 4
  head -c 4096 "$installer" | tr -c '[:print:]\n' '.' | head -n 40
  echo "--- packaging strings:"
  head -c 64000000 "$installer" \
    | grep -a -o -i -E 'makeself[^"]{0,40}|installbuilder[^"]{0,40}|bitrock[^"]{0,40}|qt installer framework[^"]{0,40}|install4j[^"]{0,40}' \
    | sort | uniq -c | head -n 20 || true
  set -o pipefail
}

if [ "$info_only" = 1 ]; then
  describe
  if [ "$kind" != rpm ]; then
    echo "--- the installer's own help:"
    cp "$installer" /tmp/diamond.run && chmod 755 /tmp/diamond.run
    if [ "$kind" = makeself ]; then sh /tmp/diamond.run --help 2>&1 | head -n 60 || true
    else timeout 60 /tmp/diamond.run --help 2>&1 | head -n 60 || true
    fi
  fi
  exit 0
fi

work=/tmp/diamond-installer
mkdir -p "$work" "$prefix"

case "$kind" in
  rpm)
    (cd / && rpm2cpio "$installer" | cpio -idm --quiet)
    ;;
  makeself)
    # Unpack without running the embedded setup, then install what is inside:
    # an .rpm, a further installer, or the Diamond tree itself.
    sh "$installer" --noexec --target "$work/x" >/dev/null
    inner=("$work"/x/*.rpm "$work"/x/**/*.rpm)
    if [ "${#inner[@]}" -ge 1 ]; then
      for r in "${inner[@]}"; do (cd / && rpm2cpio "$r" | cpio -idm --quiet); done
    else
      cp -a "$work/x/." "$prefix/"
    fi
    ;;
  installbuilder)
    cp "$installer" "$work/diamond.run" && chmod 755 "$work/diamond.run"
    "$work/diamond.run" --mode unattended --prefix "$prefix"
    ;;
  qtifw)
    cp "$installer" "$work/diamond.run" && chmod 755 "$work/diamond.run"
    QT_QPA_PLATFORM=minimal "$work/diamond.run" --root "$prefix" \
      --accept-licenses --accept-obligations --default-answer --confirm-command install
    ;;
  install4j)
    cp "$installer" "$work/diamond.run" && chmod 755 "$work/diamond.run"
    "$work/diamond.run" -q -dir "$prefix"
    ;;
  *)
    describe
    echo "Unrecognised installer: send the output above so its unattended options can be added." >&2
    exit 1
    ;;
esac
rm -rf "$work"

# Wherever it landed, Diamond's root is the directory above bin/lin64/pnmainc.
pnmainc=$(find /usr/local /opt -path '*/bin/lin64/pnmainc' -type f 2>/dev/null | head -n 1)
if [ -z "$pnmainc" ]; then
  echo "Installed, but no bin/lin64/pnmainc found under /usr/local or /opt." >&2
  exit 1
fi
root=$(dirname "$(dirname "$(dirname "$pnmainc")")")
ln -sfn "$root" /opt/diamond
echo "Diamond installed at $root, linked as /opt/diamond"
