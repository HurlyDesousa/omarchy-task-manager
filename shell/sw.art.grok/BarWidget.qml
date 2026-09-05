import QtQuick
import Quickshell.Io
import qs.Ui

// Omarchy bar widget: launch grok CLI (mise shim, user's CLI only).
//
// Click: opens a terminal running `grok` in a login shell so that mise
// shims and user PATH are fully initialised.  Does not call xAI cloud APIs.
BarWidget {
    id: root
    moduleName: "sw.art.grok"

    width: button.implicitWidth
    height: button.implicitHeight
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Process {
        id: termProc
    }

    BarIconButton {
        id: button
        bar: root.bar
        text: "󰬬"
        tooltipText: "Grok"
        onPressed: function(b) {
            if (b !== Qt.RightButton && !termProc.running) {
                termProc.command = ["/bin/bash", "-c",
                    "xdg-terminal-exec bash --login -c 'grok; exec $SHELL' 2>/dev/null" +
                    " || ghostty -e bash --login -c 'grok; exec $SHELL' 2>/dev/null" +
                    " || kitty bash --login -c 'grok; exec $SHELL' 2>/dev/null" +
                    " || true"]
                termProc.running = true
            }
        }
    }
}
