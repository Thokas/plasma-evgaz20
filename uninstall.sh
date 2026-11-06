#!/usr/bin/env bash
# Removes the EVGA Z20 widget for the current user.
set -euo pipefail
kpackagetool6 -t Plasma/Applet --remove de.thokas.evgaz20
