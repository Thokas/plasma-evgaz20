"""Drives the widget's popup parts and its settings page offscreen, a scenario at a time, with z20's
real Z20Data against a fake z20, and prints what it saw as one line, RESULT {json}, with the warnings
the package's QML gave. For tests/test_widget.py, which puts the package together and runs this in a
home of its own: python3 -I drive.py SCENARIO PACKAGE."""
import json
import os
import sys
import tempfile

from PyQt6 import sip
from PyQt6.QtCore import QMetaObject, QObject, QTimer, QUrl, pyqtSlot, qInstallMessageHandler
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
from PyQt6.QtQuick import QQuickItem, QQuickWindow

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = "/usr/share/plasma/shells/org.kde.plasma.desktop/contents/configuration/AppletConfiguration.qml"
# Not the widget's: Plasma's dialog handing every page every key, and making a page before placing it.
NOISE = ("Setting initial properties failed", "not placed in the graphics scene")
result = {"warnings": []}


class I18n(QObject):
    """Plasma's i18n() and kin: the text as written, %1, %2, ... filled in."""

    @staticmethod
    def fill(text, args):
        for i, a in reversed(list(enumerate(args))):
            text = text.replace(f"%{i + 1}", str(a if not isinstance(a, float) or a % 1 else int(a)))
        return text

    @pyqtSlot(str, result=str)
    @pyqtSlot(str, "QVariant", result=str)
    @pyqtSlot(str, "QVariant", "QVariant", result=str)
    def i18n(self, text, *args):
        return self.fill(text, args)

    @pyqtSlot(str, str, result=str)
    @pyqtSlot(str, str, "QVariant", result=str)
    def i18nc(self, context, text, *args):
        return self.fill(text, args)

    @pyqtSlot(str, str, "QVariant", result=str)
    def i18np(self, one, many, n):
        return self.fill(one if n == 1 else many, (n,))

    @pyqtSlot(str, str, str, result=str)
    @pyqtSlot(str, str, str, "QVariant", result=str)
    def i18ndc(self, domain, context, text, *args):
        return self.fill(text, args)

    @pyqtSlot(str, str, result=str)
    def i18nd(self, domain, text):
        return text


def heard(mode, context, message):
    if mode.name in ("QtWarningMsg", "QtCriticalMsg", "QtFatalMsg") and PACKAGE in (context.file or "") + message \
            and not any(n in message for n in NOISE):
        result["warnings"].append(f"{(context.file or '').split('/')[-1]}:{context.line}: {message}")


def window():
    return sip.cast(QGuiApplication.topLevelWindows()[0], QQuickWindow)


def ev(code, obj=None):
    obj = obj or window()
    e = QQmlExpression(QQmlEngine.contextForObject(obj), obj, code)
    value = e.evaluate()
    if e.hasError():
        raise RuntimeError(f"{code}: {e.error().toString()}")
    return value[0] if isinstance(value, tuple) else value


def evj(code, obj=None):
    """A JavaScript value (an array, an object) as Python's, through JSON."""
    return json.loads(ev(f"JSON.stringify({code})", obj))


def everything():
    """What is below the window: its objects (menus and their items, which aren't shown) and its items (what a
    Repeater makes has no object parent, only a parent item), each once."""
    found, seen = [], set()

    def add(o):
        key = sip.unwrapinstance(o)
        if key not in seen:
            seen.add(key)
            found.append(o)
            if isinstance(o, QQuickItem) or o.inherits("QQuickItem"):
                for child in sip.cast(o, QQuickItem).childItems():
                    add(child)
    for o in window().findChildren(QObject):
        add(o)
    add(window().contentItem())
    return found


def named(text, kind=None):
    """The objects below the window whose text is text (buttons, menu items, check boxes)."""
    return [o for o in everything()
            if o.property("text") == text and (kind is None or kind in o.metaObject().className())]


def click(text):
    found = named(text)
    if not found:
        raise RuntimeError(f"nothing says {text!r}")
    QMetaObject.invokeMethod(found[0], "click")


def home(*parts):
    return os.path.join(os.environ["HOME"], *parts)


def lines(name):
    try:
        with open(home(name)) as f:
            return f.read().splitlines()
    except OSError:
        return []


def note(**values):
    result.update(values)


# A window with z20's Z20Data (from the package) and one part of the popup on it.
POPUP = """import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import "file://%(ui)s" as Ui
import "file://%(ui)s/lib" as Lib

QQC2.ApplicationWindow {
    width: 480; height: 640; visible: true
    property alias z20: data
    property alias section: part
    Lib.Z20Data { id: data; poll: false }
    Ui.%(part)s { id: part; z20: data; width: parent.width }
}
"""

# Plasma's own settings dialog, as ConfigView gives it what it reads, with the widget's page.
DIALOG = """import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.configuration
import org.kde.plasma.plasmoid

QQC2.ApplicationWindow {
    width: 900; height: 600; visible: true
    property alias dialog: loader.item
    QtObject {
        id: configDialog
        property ConfigModel configModel: ConfigModel {
            ConfigCategory { name: "Popup"; icon: "view-list-details"; source: "file://%(ui)s/ConfigPopup.qml" }
        }
        function close() {}
    }
    ConfigModel { id: globalAppletConfigModel }
    Loader { id: loader; anchors.fill: parent; source: "file://%(shell)s" }
}
"""


def page():
    return ev("dialog.applicationWindow().pageStack.currentItem")


SCENARIOS = {
    "presets": ("PresetsSection", lambda: [
        (100, lambda: ev("z20.refresh()")),
        (3000, lambda: note(presets=evj("section.presets.map(p => p.name)"), applied=ev("section.applied"),
                            checked=[b.property("text") for b in everything()
                                     if b.property("checked") is True and b.property("text") in
                                     evj("section.presets.map(p => p.name)")])),
        (10, lambda: click("Ocean")),
        (1500, lambda: note(log=lines("z20.log"), state=lines(".local/state/z20/preset"))),
    ]),
    "profiles": ("ProfileSection", lambda: [
        (100, lambda: ev("z20.refresh()")),
        (1500, lambda: [click(t) for t in ("Name the Profiles…", "Profiles for Programs…",
                                           "Choose the Profiles Shown Here…")]),
        (1500, lambda: note(settings=lines("settings.log"), triggered=evj("Plasmoid.triggered"))),
    ]),
    "popup-page": (None, lambda: [
        (2500, lambda: note(title=ev("title", page()), shown=ev("cfg_shownProfiles", page()),
                            boxes=[b.property("text") for b in named_kind("CheckBox") if b.property("checked")])),
        (10, lambda: [QMetaObject.invokeMethod(b, "click") for b in named_kind("CheckBox")
                      if b.property("text") == "Profile 4"]),
        (300, lambda: note(shown_after=ev("cfg_shownProfiles", page()))),
        (10, lambda: click("Open EVGA Z20 Settings")),
        (1500, lambda: note(settings=lines("settings.log"))),
    ]),
}


def named_kind(kind):
    """The objects below the window of a kind (CheckBox: QML's and Qt's own class names) that say something."""
    return [o for o in everything() if kind in o.metaObject().className() and o.property("text")]


def run(steps, i=0):
    if i < len(steps):
        delay, step = steps[i]

        def go():
            try:
                step()
            except Exception as e:  # noqa: BLE001 - reported, and the run ends
                note(error=f"{type(e).__name__}: {e}")
                finish()
                return
            run(steps, i + 1)
        QTimer.singleShot(delay, go)
    else:
        finish()


def finish():
    print("RESULT " + json.dumps(result, default=str), flush=True)  # whatever it holds: the run must end
    QGuiApplication.quit()


def main():
    global PACKAGE
    scenario, PACKAGE = sys.argv[1], sys.argv[2]
    ui = os.path.join(PACKAGE, "contents", "ui")
    part, steps = SCENARIOS[scenario]
    root = os.path.join(tempfile.mkdtemp(prefix="z20widget"), "Test.qml")
    with open(root, "w") as f:
        f.write(POPUP % {"ui": ui, "part": part} if part else DIALOG % {"ui": ui, "shell": SHELL})
    qInstallMessageHandler(heard)
    app = QGuiApplication(sys.argv[:1])
    engine = QQmlApplicationEngine()
    engine.addImportPath(os.path.join(HERE, "stubs"))  # Plasmoid outside plasmashell
    i18n = I18n()
    engine.rootContext().setContextObject(i18n)
    engine.load(QUrl.fromLocalFile(root))
    if not engine.rootObjects():
        note(error="the QML didn't load")
        print("RESULT " + json.dumps(result), flush=True)
        return 1
    run(steps())
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
