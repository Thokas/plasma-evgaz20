#!/usr/bin/env bash
# Installs (or upgrades) the EVGA Z20 widget for the current user. No root needed.
# It drives z20 (https://github.com/Thokas/evga-z20), which must be
# installed first (~/.local/bin/z20, its udev rule, and its settings app,
# which the widget's pencils open). The package is plasmoid/ with z20's
# shared QML (Z20Data.qml, presets.js, macros.js from its settings app) in
# contents/ui/lib/, put together in a temporary folder.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLET_ID="de.thokas.evgaz20"
SHARED="$HOME/.local/share/z20/app/qml/lib"

for f in Z20Data.qml presets.js macros.js; do
  if [ ! -f "$SHARED/$f" ]; then
    echo "Needs z20 from 2026-11-16 on, with its settings app: $SHARED/$f is missing." >&2
    echo "Install evga-z20 first (its ./install.sh)." >&2
    exit 1
  fi
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -r "$REPO_DIR/plasmoid" "$work/plasmoid"
mkdir -p "$work/plasmoid/contents/ui/lib"
cp "$SHARED"/{Z20Data.qml,presets.js,macros.js} "$work/plasmoid/contents/ui/lib/"

# The list read whole: grep -q in a pipe stops at the match, and pipefail would count kpackagetool6's
# broken pipe as "not installed".
if grep -qx "$APPLET_ID" <<<"$(kpackagetool6 -t Plasma/Applet -l 2>/dev/null)"; then
  kpackagetool6 -t Plasma/Applet --upgrade "$work/plasmoid"
else
  kpackagetool6 -t Plasma/Applet --install "$work/plasmoid"
fi

[ -x ~/.local/bin/z20 ] || echo "Note: ~/.local/bin/z20 is missing; install evga-z20 first." >&2

cat <<MSG

Done. Show it in the system tray: right-click the tray's arrow, Configure System
Tray, Entries, "EVGA Z20": Always shown. It also works on the desktop or a panel
via Add Widgets.

If the widget was already running, restart the shell to reload it:
  systemctl --user restart plasma-plasmashell.service
MSG
