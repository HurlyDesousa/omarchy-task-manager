import QtQuick
import Quickshell.Io
import qs.Ui

// Omarchy bar widget: launch pi CLI with llama-local provider.
//
// Click: opens a terminal running `pi --provider llama-local` in a login shell
// so that mise shims and user PATH are available.  After pi exits the shell
// stays open (exec $SHELL).  Terminal preference order:
//   1. xdg-terminal-exec  (FreeDesktop standard)
//   2. ghostty -e
//   3. kitty
//
// Health dot: a small green rectangle is overlaid on the icon when
// http://127.0.0.1:8080/health returns HTTP 200 (llama-server running).
// The check runs on load and repeats every 15 s; it fails softly — no visual
// noise when llama-server is absent.
BarWidget {
  id: root
  moduleName: "sw.art.pi-local"

  property bool llamaHealthy: false

  // ── Periodic health check ─────────────────────────────────────────────────

  Timer {
    id: healthTimer
    interval: 15000
    repeat: true
    running: true
    onTriggered: {
      if (!healthProc.running) healthProc.running = true
    }
  }

  Process {
    id: healthProc
    command: ["/bin/bash", "-c",
      "curl -sf --max-time 3 'http://127.0.0.1:8080/health' >/dev/null 2>&1" +
      " && echo ok || echo fail"]
    stdout: SplitParser {
      onRead: function(line) {
        root.llamaHealthy = (line.trim() === "ok")
      }
    }
  }

  Component.onCompleted: {
    healthProc.running = true
  }

  // ── Terminal launcher ─────────────────────────────────────────────────────

  Process {
    id: termProc
  }

  // ── Bar button ────────────────────────────────────────────────────────────

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Greek small letter pi (U+03C0) — direct Unicode, no NF dependency
    text: "π"
    tooltipText: root.llamaHealthy ? "pi (local) · llama healthy ✓" : "pi (local)"
    onPressed: function(b) {
      if (b !== Qt.RightButton && !termProc.running) {
        termProc.command = ["/bin/bash", "-c",
          "xdg-terminal-exec bash --login -c 'pi --provider llama-local; exec $SHELL' 2>/dev/null" +
          " || ghostty -e bash --login -c 'pi --provider llama-local; exec $SHELL' 2>/dev/null" +
          " || kitty bash --login -c 'pi --provider llama-local; exec $SHELL' 2>/dev/null" +
          " || true"]
        termProc.running = true
      }
    }
  }

  // Green dot: shown when llama-server at 127.0.0.1:8080 is healthy.
  // Positioned bottom-right of the button so it never obscures the icon.
  Rectangle {
    visible: root.llamaHealthy
    width: 6
    height: 6
    radius: 3
    // Catppuccin Mocha green (#a6e3a1) — matches Omarchy palette
    color: "#a6e3a1"
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.bottomMargin: 4
    anchors.rightMargin: 4
    z: 1
  }
}
