# Notes for Claude

The tests are in `tests/` (`python3 -I -m unittest discover -s tests -v`):
`test_install.py` (install.sh, a fake kpackagetool6), `test_widget.py` with
`widget/drive.py` (popup parts and the settings page, scenario by scenario,
with a stand-in `Plasmoid` module in `widget/stubs`). New behavior gets a
scenario there; CI is `.forgejo/workflows/test.yml`. What's below is how they
work.

## Testing offscreen

Check QML changes offscreen first, without touching the running desktop:
installing into the live shell and restarting it is for when the user wants
to try a change. Everything below runs without a display
(`QT_QPA_PLATFORM=offscreen`). There is no `qmllint` or `qml` binary; the
distro's PyQt6 (system Qt 6) loads Kirigami, kcmutils and Plasma's QML
modules.

**Here:** One widget: `plasmoid/` (de.thokas.evgaz20), the popup and one
settings page. The editors (lighting presets, macros, profiles, programs,
presence, keyboard) are z20's settings app, in `~/Projects/evga-z20/app`,
and so is the QML both share: `Z20Data.qml`, `presets.js`, `macros.js`
(evga-z20's `app/qml/lib`), which `install.sh` copies into the package's
`contents/ui/lib/`. A test copy is put together the same way: `plasmoid/`,
then those three files into `contents/ui/lib/` (from the checkout, or from
`~/.local/share/z20/app/qml/lib` as installed). It runs z20 as
`"$HOME/.local/bin/z20"`, so a scratch `HOME` with a fake `z20` script there
stands in for the keyboard. Where the real thing is wanted (`leds`,
`presence ...`), the fake can `exec python3 -I ~/Projects/evga-z20/z20 "$@"`
(spell the path out: `~` is the scratch HOME then); with the scratch HOME it
changes only files under it, e.g. `$HOME/.config/z20/presence.ini`. Don't
let tests switch the real keyboard's profile or lighting: it is in use. The
keyboard may or may not be plugged in; live z20 checks can fail with "no
EVGA Z20 connected".

### The whole widget: plasmawindowed

`plasmawindowed` loads a package, popup included, and prints its QML errors.
For this checkout instead of the installed copy, put the package under a
scratch data dir:

```sh
d=$(mktemp -d); mkdir -p "$d/plasma/plasmoids"
cp -r PACKAGE_DIR "$d/plasma/plasmoids/PLUGIN_ID"
XDG_DATA_HOME="$d" QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 \
  timeout 10 plasmawindowed PLUGIN_ID
```

It runs until the timeout (exit 124). Nothing printed but `qml: 0` (that's
plasmawindowed's own) means no QML errors; a planted error does show up, so
the silence counts.
`QT_FORCE_STDERR_LOGGING=1` keeps Qt's messages on stderr: where stderr is
the journal (`JOURNAL_STREAM`), Qt logs there and the silence means nothing.
Give it a D-Bus of its own that starts no services (a `dbus-daemon` config
without `<servicedir>`, as `tests/` does), not the session's: there an open
plasmawindowed takes the widget over, and D-Bus starts the desktop's services
(portals, kglobalaccel, ...) for the scratch HOME, which outlive the test.

### A page or a popup part: PyQt6

Settings pages (the files `contents/config/config.qml` lists) and parts of
the popup load in a `QQC2.ApplicationWindow` (a Loader on the file's URL)
from a short PyQt6 script:

- Env: `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
  QT_QUICK_CONTROLS_STYLE=org.kde.desktop` (the default style hides sizing
  problems). With a scratch `HOME` the colors are Breeze's; for the desktop's
  own color scheme add `XDG_CONFIG_HOME=$HOME/.config` (the real one, set
  before HOME changes) and `QT_QPA_PLATFORMTHEME=kde`. Items with
  `visible: false` get no `Kirigami.Theme` colors (all black), offscreen and
  in plasmashell alike.
- i18n: a QObject with stacked `@pyqtSlot` overloads (one per argument count)
  for `i18n`, `i18nc`, `i18np`, `i18nd`, `i18ndc` that fill in %1..., set as
  `engine.rootContext().setContextObject(...)`.
- `Plasmoid`: a file that does `import org.kde.plasma.plasmoid` needs an
  applet. Outside plasmashell, put a stand-in module first on the import path
  (`engine.addImportPath(dir)`): `dir/org/kde/plasma/plasmoid/qmldir` with
  `module org.kde.plasma.plasmoid` and `singleton Plasmoid 1.0 Plasmoid.qml`;
  `Plasmoid.qml` a `pragma Singleton` QtObject with what the code uses, as
  `property var configuration: ({ someKey: "", keys() { return
  Object.keys(this).filter(k => k !== "keys"); } })`. A package that
  imports `org.kde.plasma.plasmoid 2.0` needs `singleton Plasmoid 2.0
  Plasmoid.qml` in the stand-in's qmldir and a 2.0 import in the harness too:
  after an unversioned import of it, a later 2.0 import in the same run gets
  Plasma's own module, `Plasmoid.configuration` undefined in every file.
- Commands the widget runs (Plasma5Support executable DataSource, helpers):
  point them at fakes, with a scratch `HOME` where they're started as
  `$HOME/...`, or a `PATH` with fake scripts first. Fakes that log their
  arguments let a test check what would have run; where several answers are
  read as lines, each must end with a newline.
- Ids inside the loaded file: `QQmlExpression(QQmlEngine.contextForObject(item),
  item, "someId.someFunction()")`. In PyQt6 `evaluate()` returns
  `(value, isUndefined)`; fetch objects as `JSON.stringify(...)`.
- Screenshots: `sip.cast(engine.rootObjects()[0], QQuickWindow).grabWindow()
  .save("x.png")`, then look at them. Input: `QMouseEvent`, `QWheelEvent`,
  `QKeyEvent` sent to the window, at `item.mapToScene(...)`.
- Before/after: `git archive HEAD PACKAGE_DIR | tar -x -C <scratch>` puts
  the committed version beside the working tree; run the same harness on both
  and compare the screenshots (it also shows which warnings were there before
  the change).
- Run steps one after the other (each schedules the next with
  `QTimer.singleShot`), never all at fixed offsets: coarse timers (about 5 %)
  swap steps 100 ms apart a few seconds in.

### Plasma's real settings dialog

Pages can be checked inside the dialog's own code: a Loader on
`/usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/AppletConfiguration.qml`,
made active once the rest is set up, in a file that also has

- `QtObject { id: configDialog; property ConfigModel configModel: ConfigModel
  { ConfigCategory { name: ...; icon: ...; source: "file:///.../ConfigX.qml" }
  ... }; function close() {} }` (`import org.kde.plasma.configuration`;
  sources as absolute URLs),
- `ConfigModel { id: globalAppletConfigModel }`,
- the stand-in `Plasmoid` above: the dialog hands every key of
  `Plasmoid.configuration.keys()` to each page as `cfg_<key>`.

Its "onClosing" warning is the stand-in's. The open page:
`loader.item.applicationWindow().pageStack.currentItem`, its file
`loader.item.currentSource`.

### Noise

`Setting initial properties failed: ... does not have a property called
cfg_...` and `Created graphical object was not placed in the graphics scene`
come from the dialog handing every page every config key; plasmashell's
journal has them too.
