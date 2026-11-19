"""The widget offscreen: its package put together as install.sh does it (plasmoid/, with z20's shared
QML from its settings app), then parts of the popup driven with z20's real Z20Data against a fake z20
(tests/widget/drive.py), its settings page in Plasma's own settings dialog, and the whole widget in
plasmawindowed where that is installed. A home of its own each, with a fake z20 and z20-settings.

z20's shared QML: from a checkout in Z20_REPO (CI: a clone of evga-z20), else ~/Projects/evga-z20, else
as z20 installed it. Needs PyQt6 (QtQml, QtQuick) and KDE's QML modules (see .forgejo/workflows/test.yml);
without them the tests are skipped, and with WIDGET_TESTS=required (CI) that is an error.

Run: python3 -I -m unittest discover -s tests -v
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SHARED = ("Z20Data.qml", "presets.js", "macros.js")
SHELL = "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/AppletConfiguration.qml"


def shared_qml():
    """Where z20's shared QML is, else None."""
    for d in (os.path.join(os.environ.get("Z20_REPO", ""), "app", "qml", "lib") if os.environ.get("Z20_REPO") else "",
              os.path.expanduser("~/Projects/evga-z20/app/qml/lib"),
              os.path.expanduser("~/.local/share/z20/app/qml/lib")):
        if d and all(os.path.exists(os.path.join(d, f)) for f in SHARED):
            return d
    return None


def missing():
    """What the tests need that isn't there, else ""."""
    if not shared_qml():
        return "z20's shared QML (Z20_REPO: a checkout of evga-z20)"
    try:
        from PyQt6.QtCore import QLibraryInfo
        import PyQt6.QtQml  # noqa: F401
        import PyQt6.QtQuick  # noqa: F401
    except ImportError as e:
        return str(e)
    qml = QLibraryInfo.path(QLibraryInfo.LibraryPath.QmlImportsPath)
    for module in ("org/kde/kirigami", "org/kde/kcmutils", "org/kde/plasma/plasma5support", "org/kde/plasma/components",
                   "org/kde/plasma/core", "org/kde/plasma/configuration"):
        if not os.path.exists(os.path.join(qml, module, "qmldir")):
            return f"the QML module {module.replace('/', '.')}"
    return ""


MISSING = missing()
if MISSING and os.environ.get("WIDGET_TESTS") == "required":
    raise RuntimeError(f"the widget's tests need {MISSING}")

# A status as z20 status --json gives it (the parts the widget reads): Rainbow is the stored lighting.
STATUS = {"model": "Z20 Elite ISO", "firmware": "1.38", "profile": 1, "profile_name": "DEFAULT 1",
          "game_mode": False, "game_mode_blocks": [], "nkro": True, "report_rate": 1000, "animation": None,
          "saved_animation": None, "key_colors": {}, "backlight": None, "apps": None, "keys": {},
          "changed_keys": {}, "macros": {},
          "lighting": {"effect": "wave", "colors": ["#ff0000", "#ff8000", "#ffff00", "#00ff00", "#00ffff", "#0000ff",
                                                    "#ff00ff", "#ff0000"], "direction": "right", "cycle_ms": 3000,
                       "brightness": 100}}


@unittest.skipIf(MISSING, f"the widget's tests need {MISSING}")
class Widget(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.work = tempfile.mkdtemp(prefix="z20pkg")
        cls.package = os.path.join(cls.work, "de.thokas.evgaz20")
        shutil.copytree(os.path.join(ROOT, "plasmoid"), cls.package)
        lib = os.path.join(cls.package, "contents", "ui", "lib")
        os.makedirs(lib, exist_ok=True)
        for f in SHARED:
            shutil.copy(os.path.join(shared_qml(), f), lib)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.work)

    def home(self, status=STATUS):
        home, runtime = tempfile.mkdtemp(prefix="z20home"), tempfile.mkdtemp(prefix="z20rt")
        self.addCleanup(shutil.rmtree, home)
        self.addCleanup(shutil.rmtree, runtime)
        os.makedirs(os.path.join(home, ".local", "bin"))
        shutil.copy(os.path.join(HERE, "widget", "fake_z20"), os.path.join(home, ".local", "bin", "z20"))
        shutil.copy(os.path.join(HERE, "widget", "fake_z20_settings"), os.path.join(home, ".local", "bin", "z20-settings"))
        with open(os.path.join(home, "status.json"), "w") as f:
            json.dump(status, f)
        # Nothing of the session: no display, no session bus (D-Bus would start the desktop's services for
        # this home), no XDG dirs.
        env = {k: v for k, v in os.environ.items() if not k.startswith(("QT_", "XDG_", "DBUS_"))
               and k not in ("DISPLAY", "WAYLAND_DISPLAY")}
        env.update(HOME=home, XDG_RUNTIME_DIR=runtime, XDG_CONFIG_HOME=os.path.join(home, ".config"),
                   QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                   QT_QUICK_CONTROLS_STYLE="org.kde.desktop",
                   QT_FORCE_STDERR_LOGGING="1")  # errors on stderr, never to the journal (JOURNAL_STREAM)
        return home, env

    def drive(self, scenario, status=STATUS):
        home, env = self.home(status)
        done = subprocess.run([sys.executable, "-I", os.path.join(HERE, "widget", "drive.py"), scenario, self.package],
                              env=env, capture_output=True, text=True, timeout=120)
        lines = [line for line in done.stdout.splitlines() if line.startswith("RESULT ")]
        self.assertTrue(lines, f"no result: {done.stdout}\n{done.stderr}")
        result = json.loads(lines[-1][len("RESULT "):])
        self.assertNotIn("error", result, result.get("error"))
        self.assertEqual(result["warnings"], [], "the widget's QML warned")
        return result

    def test_presets_mark_the_stored_lighting_and_a_click_applies_one(self):
        r = self.drive("presets")
        self.assertEqual(r["presets"][0], "Rainbow")  # a first start: the keyboard's, a built-in one, first
        self.assertEqual((r["applied"], r["checked"]), (0, ["Rainbow"]))
        sent = [line for line in r["log"] if line.split()[0] in ("animate", "light", "color")]
        self.assertEqual(sent[-3:], ["animate off", "light wave 0010ff 0060ff 00c0ff 00ffd0 --brightness 100 "
                                     "--cycle 6000 --direction left", "color all none"])
        self.assertEqual(r["state"], ["Ocean"])

    def test_presence_shows_what_the_service_sees(self):
        at = time.mktime((2026, 11, 19, 10, 31, 0, 0, 0, -1))
        seen = {"present": False, "since": at, "in_view": True, "sensor": True, "keyboard": True}
        r = self.drive("presence", {**STATUS, "presence": seen})
        self.assertRegex(r["state"], r"^Away since 10.31")
        self.assertFalse([line for line in r["log"] if line.startswith("sensor")])  # the service's, not its own
        r = self.drive("presence", {**STATUS, "presence": {**seen, "sensor": False}})
        self.assertEqual(r["state"], "The keyboard's sensor is off: the service can't see you")
        r = self.drive("presence", {**STATUS, "presence": None})  # the service doesn't run
        self.assertEqual(r["state"], "")

    def test_the_profile_menu_opens_the_app_or_the_widgets_settings(self):
        r = self.drive("profiles")
        self.assertEqual(r["settings"], ["[profiles]", "[programs]"])
        self.assertEqual(r["triggered"], ["configure"])

    @unittest.skipUnless(os.path.exists(SHELL), "Plasma's settings dialog (plasma-desktop-data) isn't installed")
    def test_the_popup_page_in_plasmas_settings_dialog(self):
        r = self.drive("popup-page")
        self.assertEqual(r["title"], "Popup")
        self.assertEqual(r["shown"], "1,2,3")
        self.assertEqual(r["boxes"], ["Profile 1", "Profile 2", "Profile 3"])
        self.assertEqual(r["shown_after"], "1,2,3,4")
        self.assertEqual(r["settings"], ["[]"])  # the app on its first page

    @unittest.skipUnless(shutil.which("plasmawindowed") and shutil.which("dbus-daemon"),
                         "plasmawindowed (plasma-workspace) or dbus-daemon isn't installed")
    def test_the_whole_widget_loads_in_plasmawindowed(self):
        home, env = self.home()
        data = os.path.join(home, "data", "plasma", "plasmoids")
        os.makedirs(data)
        shutil.copytree(self.package, os.path.join(data, "de.thokas.evgaz20"))
        env["XDG_DATA_HOME"] = os.path.join(home, "data")
        # A D-Bus of its own, which starts no services (plasmawindowed needs one): not the session's, where an
        # open plasmawindowed would take the widget over, and D-Bus would start services for this home.
        with open(os.path.join(home, "bus.conf"), "w") as f:
            f.write(f"<busconfig><type>session</type><listen>unix:dir={home}</listen><policy context='default'>"
                    "<allow send_destination='*' eavesdrop='true'/><allow eavesdrop='true'/><allow own='*'/>"
                    "</policy></busconfig>")
        bus = subprocess.Popen(["dbus-daemon", "--config-file", os.path.join(home, "bus.conf"), "--nofork",
                                "--print-address"], env=env, stdout=subprocess.PIPE, text=True)
        self.addCleanup(bus.stdout.close)
        self.addCleanup(bus.wait)
        self.addCleanup(bus.terminate)
        env["DBUS_SESSION_BUS_ADDRESS"] = bus.stdout.readline().strip()
        try:
            done = subprocess.run(["plasmawindowed", "de.thokas.evgaz20"], env=env, capture_output=True, text=True,
                                  timeout=10)
            output = done.stdout + done.stderr
        except subprocess.TimeoutExpired as e:  # it runs until stopped: what it said by then
            output = (e.stdout or b"").decode() + (e.stderr or b"").decode()
        errors = [line for line in output.splitlines() if "de.thokas.evgaz20" in line
                  and "Setting initial properties" not in line]
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
