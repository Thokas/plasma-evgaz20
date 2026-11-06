# plasma-evgaz20

A Plasma 6 widget for EVGA Z20 keyboards, on top of
[z20](https://github.com/Thokas/evga-z20): the active profile, Game Mode,
the lighting, what the macro keys do and the presence sensor, from the
panel or the system tray.

- **Panel icon:** a keyboard, with a gamepad in the corner while Game Mode
  is on. Middle click switches Game Mode, the wheel steps through the
  profiles, a click opens the popup.
- **Popup:**
  - profiles 1–9 with the active one's name
  - Game Mode (and the keys it blocks)
  - lighting presets: one click stores one in the active profile
  - what E1–E5 do, and how many other keys differ from the factory
  - whether someone is at the desk, what the keyboard does when you
    leave, and a switch for z20's presence service (lock the screen and
    the like, set up in `~/.config/z20/presence.ini`)
- **Settings** (the configure button at the top of the popup, the pencil
  next to "Lighting", or right-click, Configure):
  - **Lighting presets:** build the presets the popup offers: effect,
    up to 8 colors, brightness, speed and direction. "Try on the keyboard"
    shows one without storing it; "Back to stored" undoes that. Comes with
    a few to start from (rainbow wave, ocean, sunset, spiral, stars, …).
  - **Keyboard:** report rate, n-key rollover and the keys Game Mode
    blocks; these apply at once. N-key rollover on (the normal case) means
    any number of keys can be down at once; off limits it to six plus the
    modifiers, which only some BIOS setups and KVM switches need.
- **Right-click menu:** back up the keyboard (`z20 backup`), back to the
  stored lighting (`z20 light reload`).

It reads the keyboard every 3 s while the popup is open, every 30 s
otherwise, and at once when the keyboard reports a change made with its own
keys (`z20 events`). Every change runs `z20`; lighting changes from the
widget are stored in the keyboard's profile. Without a keyboard, the
widget sits among the tray's hidden entries.

> [!WARNING]
> **Written entirely by AI.** Like z20, this widget was written by an AI
> assistant (Claude, in Claude Code) from a person's prompts and checked by
> using it, not by a person reading every line.

## Install

Needs z20 installed (`~/.local/bin/z20`, with its udev rule), see
[evga-z20](https://github.com/Thokas/evga-z20).

```
git clone https://github.com/Thokas/plasma-evgaz20.git && cd plasma-evgaz20
./install.sh
```

Then show it in the system tray (right-click the tray's arrow, Configure
System Tray, Entries, "EVGA Z20": Always shown), or add it to a panel or
the desktop via Add Widgets. After an update, restart the shell:
`systemctl --user restart plasma-plasmashell.service`.

## Uninstall

```
./uninstall.sh
```

## License

MIT, see [LICENSE](LICENSE). Not made or endorsed by EVGA.
