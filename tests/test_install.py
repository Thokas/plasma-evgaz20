"""install.sh, with a fake kpackagetool6 and a home of its own: it stops without z20's settings app, and
puts the package together (plasmoid/ with z20's shared QML) in a temporary folder, then installs or
upgrades it. Needs only bash.

Run: python3 -I -m unittest discover -s tests -v
"""
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = ("Z20Data.qml", "presets.js", "macros.js")
# Records its arguments; -l lists $HOME/installed; --install / --upgrade keep a copy of the package.
KPACKAGETOOL = """#!/bin/sh
echo "$*" >> "$HOME/kpackagetool.log"
case "$*" in
  *" -l") cat "$HOME/installed" 2>/dev/null ;;
  *--install*|*--upgrade*) rm -rf "$HOME/package"; cp -r "$4" "$HOME/package" ;;
esac
"""


class Install(unittest.TestCase):

    def run_install(self, shared=True, installed=False):
        home = tempfile.mkdtemp(prefix="z20home")
        self.addCleanup(shutil.rmtree, home)
        bin_dir = os.path.join(home, "bin")
        os.makedirs(bin_dir)
        with open(os.path.join(bin_dir, "kpackagetool6"), "w") as f:
            f.write(KPACKAGETOOL)
        os.chmod(os.path.join(bin_dir, "kpackagetool6"), 0o755)
        if shared:
            lib = os.path.join(home, ".local", "share", "z20", "app", "qml", "lib")
            os.makedirs(lib)
            for name in SHARED:
                with open(os.path.join(lib, name), "w") as f:
                    f.write(f"// z20's {name}\n")
        if installed:
            with open(os.path.join(home, "installed"), "w") as f:
                f.write("org.kde.plasma.digitalclock\nde.thokas.evgaz20\n")
        env = dict(os.environ, HOME=home, PATH=bin_dir + os.pathsep + os.environ["PATH"])
        done = subprocess.run(["bash", os.path.join(ROOT, "install.sh")], env=env, capture_output=True, text=True,
                              timeout=60)
        log = os.path.join(home, "kpackagetool.log")
        calls = open(log).read().splitlines() if os.path.exists(log) else []
        return done, calls, home

    def test_without_z20s_settings_app_it_stops(self):
        done, calls, _ = self.run_install(shared=False)
        self.assertEqual(done.returncode, 1)
        self.assertIn("Needs z20 from 2026-11-16 on", done.stderr)
        self.assertEqual(calls, [])

    def test_a_new_install_has_the_shared_qml_in_the_package(self):
        done, calls, home = self.run_install()
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual([c.split()[2] for c in calls], ["-l", "--install"])
        package = os.path.join(home, "package")
        for name in SHARED:
            with open(os.path.join(package, "contents", "ui", "lib", name)) as f:
                self.assertEqual(f.read(), f"// z20's {name}\n")
        self.assertTrue(os.path.exists(os.path.join(package, "metadata.json")))
        self.assertTrue(os.path.exists(os.path.join(package, "contents", "ui", "main.qml")))
        self.assertFalse(os.path.exists(os.path.join(ROOT, "plasmoid", "contents", "ui", "lib")),
                         "the checkout stays as it is")

    def test_an_installed_widget_is_upgraded(self):
        done, calls, _ = self.run_install(installed=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual([c.split()[2] for c in calls], ["-l", "--upgrade"])


if __name__ == "__main__":
    unittest.main()
