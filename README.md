# plasma-evgaz20

A Plasma 6 widget for EVGA Z20 keyboards, on top of
[z20](https://github.com/Thokas/evga-z20): the active profile, Game Mode,
the lighting, what the macro keys do and the presence sensor, from the
panel or the system tray.

- **Panel icon:** a keyboard, with a gamepad in the corner while Game Mode
  is on. Middle click switches Game Mode, the wheel steps through the
  profiles the popup shows, a click opens the popup.
- **Game Mode on:** Plasma's OSD (the volume keys' popup) says so, also
  over fullscreen games, however it was switched on (its key, the popup, z20).
- **Popup:**
  - the profiles you chose, by name (all nine in the menu next to them);
    while z20's apps service has the keyboard on one for a program, which
    one: "For Cyberpunk 2077 · back to Work when it ends"
  - Game Mode (and the keys it blocks)
  - lighting presets: one click applies one. The keyboard's own effects
    are stored in the active profile; the software ones (aurora, fire,
    rain, ripples, scanner, gradient) run as z20's animate service, also
    after login; keys with colors of their own get them over the effect
    (`z20 color`)
  - the keyboard light: how bright the lighting is, of how it is set,
    dark while Plasma has its keyboard light off (when the screen dims or
    goes off); kept by z20's backlight service, which the slider starts
    (needs z20 from 2026-11-12 on)
  - which macro E1–E5 run and how (once, a number of times, toggle,
    while held), changed right there; the same for every other key or
    Fn layer that runs one, and "Another Key" puts a macro on any key.
    Below, how many other keys differ from the factory (the pencil there
    leads to the macros)
  - whether someone is at the desk, or that nothing is in the sensor's
    view (its beam is narrow: leaning back can take you out of it, and the
    distance it then reports means nothing), the distance over the last two
    minutes against the distance that counts as present, what the keyboard
    does when you leave, and a switch for z20's presence service with what
    it does (lock the screen, a lighting while you're away and the like,
    set up in the settings)
- **Settings:** the editors are z20's settings app (`z20-settings`, in the
  application menu as "EVGA Z20"). The configure button at the top of the
  popup opens it, the pencils next to "Lighting", "Macro keys" and
  "Presence" and the profile menu's entries open it on their page:
  lighting presets on a drawing of the keyboard with colors per key,
  macros, profile names, profiles for programs, what happens when you
  leave, and the keyboard's own settings (see
  [evga-z20](https://github.com/Thokas/evga-z20)). The presets are
  kept in `~/.config/z20/presets.json`, for the app and the popup alike;
  those kept in the widget before move there once. The widget's own
  settings (right-click, Configure, or "Choose the Profiles Shown Here" in
  the profile menu) are which profiles the popup shows as buttons.
- **Right-click menu:** open the settings app, back up the keyboard
  (`z20 backup`), back to the stored lighting (`z20 light reload`, and the
  saved software effect).

It reads the keyboard every 3 s while the popup is open (the distance every
second, for the graph), every 30 s otherwise, and at once when the keyboard
reports a change made with its own keys (`z20 events`; media keys and the
volume wheel don't count). Every change runs `z20`, one at a time in the
order you made them; until a read shows a change, the popup shows it as
made, so a quick second change builds on the first. Without a keyboard, the
widget sits among the tray's hidden entries.

> [!WARNING]
> **Written entirely by AI.** Like z20, this widget was written by an AI
> assistant (Claude, in Claude Code) from a person's prompts and checked by
> using it, not by a person reading every line.

## Install

Needs z20 installed (`~/.local/bin/z20`, with its udev rule), from
2026-11-16 on with its settings app: `install.sh` puts the package
together from `plasmoid/` and the settings app's shared QML
(`~/.local/share/z20/app/qml/lib`: `Z20Data.qml`, `presets.js`,
`macros.js`, which are kept in evga-z20 only). See
[evga-z20](https://github.com/Thokas/evga-z20).

```
git clone https://github.com/Thokas/plasma-evgaz20.git && cd plasma-evgaz20
./install.sh
```

Then show it in the system tray (right-click the tray's arrow, Configure
System Tray, Entries, "EVGA Z20": Always shown), or add it to a panel or
the desktop via Add Widgets. After an update, restart the shell:
`systemctl --user restart plasma-plasmashell.service`.

## Tests

```
python3 -I -m unittest discover -s tests -v
```

`tests/test_install.py` runs `install.sh` against a fake `kpackagetool6`:
it stops without z20's settings app, and puts the package together with
z20's shared QML. `tests/test_widget.py` puts the package together the
same way (z20's shared QML from `$Z20_REPO`, a checkout of evga-z20, else
`~/Projects/evga-z20` or z20 as installed) and runs, offscreen with z20's
real `Z20Data` against a fake `z20`: the presets (the stored lighting
marked, a click applying one), the profile menu (opening the app on its
page, or the widget's settings), the settings page in Plasma's own
settings dialog, and the whole widget in `plasmawindowed` where that is
installed; any warning from the widget's QML fails. They need PyQt6 and
KDE's QML modules, else they are skipped. Forgejo runs them on every push
(`.forgejo/workflows/test.yml`; the repository secret `EVGA_Z20_TOKEN`
lets it clone evga-z20).

## Uninstall

```
./uninstall.sh
```

## License

MIT, see [LICENSE](LICENSE). Not made or endorsed by EVGA.
