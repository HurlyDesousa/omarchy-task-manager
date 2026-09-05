import QtQuick
import Quickshell.Io
import qs.Ui

// Omarchy bar widget: launch grok CLI (mise shim, user's CLI only).
//
// Click: opens a terminal running `grok` in a login shell so that mise
// shims and user PATH are fully initialised.  After grok exits the shell
// stays open (exec $SHELL).  Terminal preference order:
//   1. xdg-terminal-exec  (FreeDesktop standard)
//   2. ghostty -e
//   3. kitty
//
// This widget launches the user's local grok CLI exclusively.  It does not
// call xAI cloud APIs or inject API tokens — authentication is the user's
// responsibility within the CLI session.
BarWidget {
  id: root
  moduleName: "sw.art.grok"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: termProc
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-md-alpha-x-circle (U+F0B2C) — stylised X representing xAI / Grok
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
