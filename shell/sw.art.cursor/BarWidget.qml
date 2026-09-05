import QtQuick
import Quickshell.Io
import qs.Ui

// Omarchy bar widget: launch Cursor IDE.
// Click: exec ~/.local/bin/cursor; fallback to cursor on PATH.
// No terminal — Cursor is a GUI application.
BarWidget {
    id: root
    moduleName: "sw.art.cursor"

    width: button.implicitWidth
    height: button.implicitHeight
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Process {
        id: launchProc
    }

    BarIconButton {
        id: button
        bar: root.bar
        // nf-md-cursor-pointer — pointer/cursor icon
        text: "󱃸"
        tooltipText: "Cursor"
        onPressed: function(b) {
            if (b !== Qt.RightButton && !launchProc.running) {
                launchProc.command = ["/bin/bash", "-c",
                    "exec \"${HOME}/.local/bin/cursor\" 2>/dev/null" +
                    " || exec cursor 2>/dev/null || true"]
                launchProc.running = true
            }
        }
    }
}
