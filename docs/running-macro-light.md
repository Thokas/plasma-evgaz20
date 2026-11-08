# Lighting the key of a running macro

Not built. The idea: while a macro runs, above all one that runs until its
key is pressed again (toggle), its key lights up, so you can see that it
runs. These notes are where it stands (2026-11-08).

## What's in the way

The keyboard runs macros itself. A key that runs a macro sends only what
the macro does: keystrokes on USB interface 0, clicks and media keys on
interface 1. Nothing tells the computer that the key was pressed, or that
a macro started or ended.

The only way found to see the press is command `33` of report 4, known
from Unleash's code: "key position reports". Written as 1, the keyboard is
said to report the position of every key pressed on interface 1, as the
status report `03 06 <position>` (z20 already names status 6 "key
position" in `STATUS_EVENTS`, so `z20 events` would print it). Nobody has
tried it. z20 refuses to send it: it isn't in z20's list of commands
(`GENERAL` / `GENERAL_WRITES`).

## Open questions

1. Does the firmware (1.38) take command `33` at all?
2. Does the keyboard still type while it's on, or does it swallow the keys
   (as when Unleash asks you to press the key to pick)?
3. Which position comes for E1-E5 (z20's positions: 21, 43, 65, 82, 102)?
4. Does letting go of a key send a report too? "While held" needs it.
5. Does it stay on after unplugging, or after a reboot?

`tools/probe_keypos.py` answers 1-4.

## Privacy

z20 opens only interface 1, because interfaces 0 and 2 carry every
keystroke. While command `33` is on, interface 1 reports the position of
every key you press, and every program of the logged-in user can read
interface 1 (the udev rule gives it to the user). That is a keylogger that
needs no root. z20 could pass on only the keys that run a macro, but the
reports still reach every program that opens the device.

Decide whether that is acceptable before building anything on it.

## How it could work

If the answers are yes:

- **z20:** allow command `33`, and add a small service (like
  z20-presence) that keeps the reports on and watches the keys that run a
  macro in the active profile. It tracks each macro by its run mode:
  - toggle (`08`): every press flips it on or off
  - once / N times (`09`, `0B`): it runs about as long as its waits, plus
    2.5 ms per step, times N
  - while held (`0C`): from the press to the release, if releases are
    reported
- **The light:** the per-LED colors (report 6, what `z20 color e1 …`
  sends), set by that service. It has to live in z20: `z20 animate`
  repaints every LED 25 times a second and would paint over a light set
  from outside, so the service merges the key's color into those frames.
- **Not in the widget:** the widget's `z20 events --wait 30` starts again
  after every event, so a quick second press could be missed and a toggle
  would show the wrong way round. The widget could still show what runs
  in "Macro keys", from what the service reports.

## Running the probe

With the keyboard plugged in, from this repository:

```
python3 -I tools/probe_keypos.py
```

It loads z20 from `~/.local/bin/z20`, writes `33` = 1 straight to the
keyboard (past z20's list of commands), prints every input report on
interface 1 for 20 s, and writes `33` = 0 again, also on Ctrl+C or an
error. While it runs: type a few letters (do they appear?), press E1 twice,
hold a letter for a second. Afterwards, check that the keyboard types
normally. It prints the position of every key you press, so don't type
anything secret while it runs.

## Results

Not run yet.
