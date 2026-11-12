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
  - the profiles you chose, by name (all nine in the menu next to them)
  - Game Mode (and the keys it blocks)
  - lighting presets: one click applies one. The keyboard's own effects
    are stored in the active profile; the software ones (aurora, fire,
    rain, ripples, scanner, gradient) run as z20's animate service, also
    after login
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
- **Settings** (the configure button at the top of the popup, the pencils
  next to "Lighting", "Macro keys" and "Presence", or right-click,
  Configure):
  - **Lighting presets:** build the presets the popup offers: effect,
    up to 8 colors, brightness, speed and direction. "Try on the keyboard"
    shows one without storing it; "Back to stored" undoes that. Comes with
    a few to start from (rainbow wave, ocean, aurora, fire, matrix, …);
    "Add Built-in Presets" brings back the ones not in the list.
  - **Profiles:** which profiles the popup shows (the active one always
    does) and their names, stored in the keyboard.
  - **Macros:** the macros stored in the keyboard, listed by name with a
    search, each with a short line of its steps and the keys that run it;
    write new ones, change their name and steps, delete them. Picking
    another macro with changes not stored asks first. The steps show as a
    list: keys as
    keycaps (pressed, held down or let go, with a bar along the side while
    a key is held), clicks, wheel, media keys, and waits with a bar for
    their length. Pick a step to change it; add steps from a menu or
    record them from the keys you press (optionally with the pauses
    between them); move and remove them with the buttons or the keyboard
    (Ctrl+Up / Down, Delete). The length, the run time and the room left
    in the keyboard show under the list. "As Text" shows the steps as
    lines, as `z20 macros` prints them (`LShift down`, `H`, `wait 20 ms`),
    to paste or type. "Store in the Keyboard" writes the macro; z20 keeps
    the one it replaces in `~/.local/state/z20/previous`.
  - **Presence:** what z20's presence service does each time you leave the
    desk and come back: after how many seconds away you count as gone,
    lock the screen, pause media (and play it on), the screens off, and
    the keyboard's lighting while you're away, one of the lighting
    presets, shown without being stored; the stored lighting comes back
    with you. With nothing else ticked, a lighting is all that happens:
    the keyboard lights up instead of the screen locking. Below, what the
    keyboard itself does when you leave (lights off, Win+L, sleep), stored
    in the active profile; it does that only the first time after being
    plugged in. Written to `~/.config/z20/presence.ini` with
    `z20 presence set`; these apply at once.
  - **Keyboard:** report rate, n-key rollover and the keys Game Mode
    blocks; these apply at once. N-key rollover on (the normal case) means
    any number of keys can be down at once; off limits it to six plus the
    modifiers, which only some BIOS setups and KVM switches need.
- **Right-click menu:** back up the keyboard (`z20 backup`), back to the
  stored lighting (`z20 light reload`, and the saved software effect).

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

Needs z20 installed (`~/.local/bin/z20`, with its udev rule; from
2026-11-11 on, with `z20 presence set`), see
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
