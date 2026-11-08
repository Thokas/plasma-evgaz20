#!/usr/bin/env python3
"""Does the Z20 report which key is pressed (command 33, from Unleash's code, never checked)?

The question behind lighting the key of a running macro: see docs/running-macro-light.md.
Uses z20 (~/.local/bin/z20) as a library; run it with the keyboard plugged in:

  python3 -I tools/probe_keypos.py

Turns key position reports on for 20 s, prints every input report on interface 1, and turns
them off again (also on Ctrl+C or an error). While it runs:
  1. type a few letters: do they still appear in this terminal? (does the keyboard still type?)
  2. press E1 (and another E key) twice: does a "key position" report come, and which number?
  3. hold a letter for a second: does a second report come when it is let go?
Afterwards: does the keyboard type normally again?
"""
import fcntl, importlib.machinery, importlib.util, os, select, sys, time

loader = importlib.machinery.SourceFileLoader("z20", os.path.expanduser("~/.local/bin/z20"))
spec = importlib.util.spec_from_loader("z20", loader)
z20 = importlib.util.module_from_spec(spec)
loader.exec_module(z20)

KEYPOS = 0x33


def raw_general(kb, sub, value):
    """Command 33 straight to the keyboard: z20 itself refuses it (not in its list of commands)."""
    report = bytearray(bytes([4, *z20.HEADER, KEYPOS, sub, 0, 0, value]).ljust(z20.SIZES[4], b"\0"))
    answer = bytearray(len(report))
    answer[0] = 4
    fcntl.ioctl(kb.fd, z20.ioc(0x06, len(report)), report, True)
    time.sleep(0.02)
    fcntl.ioctl(kb.fd, z20.ioc(0x07, len(answer)), answer, True)
    status = {z20.SUCCESS: "ok", z20.FAIL: "REFUSED"}.get(answer[6], f"status {answer[6]:02x}")
    return f"{bytes(answer[:10]).hex(' ')} ({status})"


kb = z20.Keyboard()
path = z20.find_keyboard()[0]
events = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
print("read 33 before:", raw_general(kb, z20.READ, 0))
try:
    print("write 33 = 1:  ", raw_general(kb, z20.WRITE, 1))
    print("read 33 now:   ", raw_general(kb, z20.READ, 0))
    print("\n20 s: type a few letters, press E1 twice, hold a letter for a second ...\n", flush=True)
    end = time.monotonic() + 20
    while time.monotonic() < end:
        if not select.select([events], [], [], max(0, end - time.monotonic()))[0]:
            continue
        data = os.read(events, 64)
        text = z20.interface_event(data)
        if data[:2] == b"\x03\x06" and len(data) > 2:
            text += f"  -> {z20.KEY_POSITIONS.get(data[2], '?')}"
        print(f"{time.strftime('%H:%M:%S')}  {text}", flush=True)
finally:
    print("\nwrite 33 = 0:  ", raw_general(kb, z20.WRITE, 0))
    print("read 33 after: ", raw_general(kb, z20.READ, 0))
    os.close(events)
