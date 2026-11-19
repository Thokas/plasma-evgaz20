# Changelog

All notable changes to plasma-evgaz20. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- The popup's presence part shows what z20's presence service sees (at the
  desk or away, since when), from `z20 status`, instead of reading the
  sensor itself; the distance graph and what the keyboard itself does are
  on the settings app's Presence page now. Needs evga-z20 from
  2026-11-19 on for the service's view; with an older one, only the
  switch shows.

## [0.1.0] - 2026-11-17

The first release. Needs [evga-z20](https://github.com/Thokas/evga-z20)
0.1.0 or later, with its settings app, and Plasma 6.

### Added

- A Plasma 6 widget for EVGA Z20 keyboards, for the panel, the system
  tray or the desktop, on top of z20.
- **Panel icon**: a keyboard, with a gamepad while Game Mode is on.
  Middle click switches Game Mode, the wheel steps through the profiles,
  a click opens the popup.
- **Game Mode OSD**: Plasma's on-screen display says when Game Mode turns
  on, also over fullscreen games, however it was switched on.
- **Popup**:
  - the profiles you chose, by name, and which one z20's apps service
    has the keyboard on for a running program;
  - Game Mode and the keys it blocks;
  - lighting presets, one click each, the one the keyboard has stored
    marked; the software effects run as z20's animate service;
  - a slider for the Z20's own keyboard light (z20's backlight service);
  - what the macro keys E1–E5 (and any other key running a macro) do,
    changed right there, with a lock so scrolling the popup changes no
    key;
  - the presence sensor: whether someone is at the desk or nothing is in
    view, the distance over the last two minutes, what the keyboard does
    when you leave, and a switch for z20's presence service.
- **Settings**: the editors are z20's settings app; the popup's configure
  button, its pencils and the profile menu open it on the right page. The
  widget's own settings choose the profiles shown as buttons.
- **Right-click menu**: open the settings app, back up the keyboard, back
  to the stored lighting.
- Changes run `z20` one at a time, in the order made, shown as made until
  a read confirms them; failed commands also go to the journal.
- Without a keyboard, the widget sits among the tray's hidden entries.
- `install.sh` (puts the package together from `plasmoid/` and z20's
  shared QML) and `uninstall.sh`.
- Tests: `install.sh` against a fake `kpackagetool6`, and the popup and
  the settings page offscreen against a fake `z20`.

[Unreleased]: https://github.com/Thokas/plasma-evgaz20/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Thokas/plasma-evgaz20/releases/tag/v0.1.0
