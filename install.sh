#!/usr/bin/env bash
# Installs (or upgrades) the EVGA Z20 widget for the current user. No root needed.
# It drives z20 (https://github.com/Thokas/evga-z20), which must be
# installed first (~/.local/bin/z20 and its udev rule).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLET_ID="de.thokas.evgaz20"

if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$APPLET_ID"; then
  kpackagetool6 -t Plasma/Applet --upgrade "$REPO_DIR/plasmoid"
else
  kpackagetool6 -t Plasma/Applet --install "$REPO_DIR/plasmoid"
fi

[ -x ~/.local/bin/z20 ] || echo "Note: ~/.local/bin/z20 is missing; install evga-z20 first." >&2

cat <<MSG

Done. Show it in the system tray: right-click the tray's arrow, Configure System
Tray, Entries, "EVGA Z20": Always shown. It also works on the desktop or a panel
via Add Widgets.

If the widget was already running, restart the shell to reload it:
  systemctl --user restart plasma-plasmashell.service
MSG
