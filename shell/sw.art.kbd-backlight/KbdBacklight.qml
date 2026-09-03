// Omarchy bar widget: keyboard RGB backlight control.
// Drives /usr/local/bin/x1e-ec-tool kb '#rrggbb' (solid color, ASUS Vivobook x1e).
//
// State file (Omarchy idle-helper contract):
//   ~/.local/state/omarchy/task-manager/kbd-backlight
//   JSON: {"hex":"#rrggbb","enabled":true}
//   Written atomically (mktemp + rename) on every change AND on startup apply.
//   Idle helper: dim → kb #000000; activity → if enabled, kb hex from file.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Ui

BarWidget {
    id: root
    moduleName: "sw.art.kbd-backlight"

    // ── Live state ──────────────────────────────────────────────────────────
    // baseHex: full-brightness chosen color (#rrggbb).
    // brightness: 0–100; scales RGB channels of baseHex linearly.
    // kbdEnabled: explicit off toggle.
    // actualHex: computed color sent to EC and written as "hex" in state file.
    property string  baseHex:    "#ffffff"
    property int     brightness: 100
    property bool    kbdEnabled: true

    readonly property string actualHex: {
        if (!kbdEnabled || brightness === 0) return "#000000"
        if (brightness === 100) return baseHex.toLowerCase()
        var h = baseHex.slice(1).toLowerCase()
        if (h.length === 3) h = h[0]+h[0]+h[1]+h[1]+h[2]+h[2]
        function sc(off) {
            var v = Math.max(0, Math.min(255,
                Math.round(parseInt(h.substr(off, 2), 16) * brightness / 100)))
            var s = v.toString(16)
            return s.length < 2 ? "0"+s : s
        }
        return "#" + sc(0) + sc(2) + sc(4)
    }

    // ── Debounce timers ─────────────────────────────────────────────────────
    // Prevents spamming the EC or disk during slider drags.
    Timer {
        id: applyTimer
        interval: 100
        repeat: false
        onTriggered: root._doApply()
    }

    Timer {
        id: saveTimer
        interval: 150
        repeat: false
        onTriggered: root._doSave()
    }

    // ── Processes ───────────────────────────────────────────────────────────
    Process {
        id: ecProc
        onRunningChanged: {
            if (!running && applyTimer.running) applyTimer.restart()
        }
    }

    Process {
        id: saveProc
        onRunningChanged: {
            if (!running && saveTimer.running) saveTimer.restart()
        }
    }

    // ── Startup: read saved state then apply ────────────────────────────────
    Process {
        id: initProc
        stdout: SplitParser {
            onRead: function(line) {
                var l = line.trim()
                if (!l || l === "{}") return
                try {
                    var d = JSON.parse(l)
                    // Restore the base colour for the UI.
                    // _base holds the pre-scaled colour written by previous builds;
                    // fall back to hex itself (which is actualHex at save time).
                    var col = (d._base && /^#[0-9a-fA-F]{6}$/.test(d._base))
                        ? d._base.toLowerCase()
                        : ((d.hex && /^#[0-9a-fA-F]{6}$/.test(d.hex))
                            ? d.hex.toLowerCase() : null)
                    if (col) root.baseHex = col

                    if (typeof d.brightness === "number")
                        root.brightness = Math.max(0, Math.min(100, Math.round(d.brightness)))

                    if (typeof d.enabled === "boolean")
                        root.kbdEnabled = d.enabled
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (!running) {
                // Apply the restored colour to the EC immediately.
                root._doApply()
                // Write the file in the canonical format (normalises any old format).
                root._doSave()
            }
        }
    }

    Component.onCompleted: {
        initProc.command = ["/bin/bash", "-c",
            "cat \"$HOME/.local/state/omarchy/task-manager/kbd-backlight\" 2>/dev/null" +
            " || echo '{}'"]
        initProc.running = true
    }

    // ── Internal helpers ────────────────────────────────────────────────────
    function _doApply() {
        if (ecProc.running) { applyTimer.restart(); return }
        var hex = actualHex
        ecProc.command = ["/bin/bash", "-c",
            "ec=/usr/local/bin/x1e-ec-tool;" +
            " \"$ec\" kb '" + hex + "' 2>/dev/null ||" +
            " sudo -n \"$ec\" kb '" + hex + "' 2>/dev/null || true"]
        ecProc.running = true
    }

    // Writes the canonical idle-helper contract file atomically.
    // Format: {"hex":"#rrggbb","enabled":true}
    // hex = actualHex (the exact colour currently sent to the EC).
    // enabled = kbdEnabled && brightness > 0.
    function _doSave() {
        if (saveProc.running) { saveTimer.restart(); return }
        var en = kbdEnabled && brightness > 0
        var payload = '{"hex":"' + actualHex + '","enabled":' + (en ? "true" : "false") + '}'
        saveProc.command = ["/bin/bash", "-c",
            "d=\"$HOME/.local/state/omarchy/task-manager\";" +
            " mkdir -p \"$d\" &&" +
            " t=$(mktemp \"$d/kbd-backlight.XXXXXX\") &&" +
            " printf '%s\\n' '" + payload + "' > \"$t\" &&" +
            " mv \"$t\" \"$d/kbd-backlight\""]
        saveProc.running = true
    }

    // Public: call after any state change that should be persisted + applied.
    function applyAndSave() {
        applyTimer.restart()
        saveTimer.restart()
    }

    // Validate and normalise a hex string to lowercase #rrggbb, or return null.
    function normaliseHex(s) {
        s = s.trim().toLowerCase()
        if (/^#[0-9a-f]{6}$/.test(s)) return s
        if (/^#[0-9a-f]{3}$/.test(s))
            return "#" + s[1]+s[1]+s[2]+s[2]+s[3]+s[3]
        if (/^[0-9a-f]{6}$/.test(s)) return "#" + s
        if (/^[0-9a-f]{3}$/.test(s))
            return "#" + s[0]+s[0]+s[1]+s[1]+s[2]+s[2]
        return null
    }

    // ── Bar button ──────────────────────────────────────────────────────────
    implicitWidth:  button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: (root.kbdEnabled && root.brightness > 0) ? "󰌌" : "󰌎"
        tooltipText: (root.kbdEnabled && root.brightness > 0)
            ? ("Keyboard: " + root.actualHex + " @ " + root.brightness + "%")
            : "Keyboard: off"
        onPressed: function(b) {
            if (b !== Qt.RightButton) {
                if (popover.visible) popover.close()
                else                 popover.open()
            }
        }
    }

    // ── Popover ─────────────────────────────────────────────────────────────
    Popup {
        id: popover
        parent: root
        // Centre over the bar button; Qt clamps to screen edges.
        x: Math.round((root.width - width) / 2)
        y: root.height + 2
        width: 272
        padding: 0
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            radius: 8
        }

        contentItem: ColumnLayout {
            spacing: 0
            width: popover.width

            // ── Header ────────────────────────────────────────────────────
            Label {
                text: "Keyboard Backlight"
                font.pixelSize: 13
                font.bold: true
                color: "#cdd6f4"
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.bottomMargin: 8
            }

            Rectangle { height: 1; color: "#45475a"; Layout.fillWidth: true }

            ColumnLayout {
                spacing: 10
                Layout.topMargin: 12
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Layout.bottomMargin: 14

                // ── Colour presets ────────────────────────────────────────
                RowLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    Repeater {
                        model: ["#ffffff", "#ffd080", "#ff3333", "#ff8800",
                                "#33ee44", "#00eeee", "#3388ff", "#cc44ff"]
                        delegate: Rectangle {
                            property string swatch: modelData
                            width: 26; height: 26; radius: 5
                            color: swatch
                            border.width: 2
                            border.color: (root.baseHex.toLowerCase() === swatch)
                                ? "#cdd6f4" : "transparent"
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.baseHex = swatch
                                    hexInput.text = swatch
                                    if (!root.kbdEnabled) root.kbdEnabled = true
                                    if (root.brightness === 0) root.brightness = 100
                                    root.applyAndSave()
                                }
                            }
                        }
                    }
                }

                // ── Hex entry ─────────────────────────────────────────────
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Label {
                        text: "Hex"
                        color: "#a6adc8"
                        font.pixelSize: 12
                    }

                    TextField {
                        id: hexInput
                        text: root.baseHex
                        font.family: "monospace"
                        font.pixelSize: 12
                        color: "#cdd6f4"
                        Layout.fillWidth: true
                        leftPadding: 6; rightPadding: 6
                        topPadding: 4; bottomPadding: 4
                        background: Rectangle {
                            color: "#313244"
                            radius: 4
                            border.color: hexInput.activeFocus ? "#89b4fa" : "#45475a"
                            border.width: 1
                        }
                        onEditingFinished: {
                            var v = root.normaliseHex(text)
                            if (!v) { text = root.baseHex; return }
                            root.baseHex = v
                            text = v
                            if (!root.kbdEnabled) root.kbdEnabled = true
                            if (root.brightness === 0) root.brightness = 100
                            root.applyAndSave()
                        }
                        Connections {
                            target: root
                            function onBaseHexChanged() {
                                if (!hexInput.activeFocus) hexInput.text = root.baseHex
                            }
                        }
                    }

                    // Live preview swatch.
                    Rectangle {
                        width: 22; height: 22; radius: 4
                        color: root.actualHex
                        border.color: "#45475a"; border.width: 1
                    }
                }

                // ── Brightness slider ─────────────────────────────────────
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Label {
                        text: "Bright"
                        color: "#a6adc8"
                        font.pixelSize: 12
                    }

                    Slider {
                        id: brightSlider
                        from: 0; to: 100; stepSize: 1
                        value: root.brightness
                        Layout.fillWidth: true

                        handle: Rectangle {
                            x: brightSlider.leftPadding +
                               brightSlider.visualPosition * (brightSlider.availableWidth - width)
                            y: brightSlider.topPadding +
                               brightSlider.availableHeight / 2 - height / 2
                            implicitWidth: 14; implicitHeight: 14
                            radius: 7
                            color: "#89b4fa"
                            border.color: "#1e1e2e"; border.width: 1
                        }

                        background: Rectangle {
                            x: brightSlider.leftPadding
                            y: brightSlider.topPadding + brightSlider.availableHeight / 2 - height / 2
                            width: brightSlider.availableWidth; height: 4; radius: 2
                            color: "#313244"
                            Rectangle {
                                width: brightSlider.visualPosition * parent.width
                                height: parent.height; radius: parent.radius
                                color: "#89b4fa"
                            }
                        }

                        onMoved: {
                            root.brightness = Math.round(value)
                            root.applyAndSave()
                        }
                    }

                    Label {
                        text: root.brightness + "%"
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        Layout.minimumWidth: 36
                    }
                }

                // ── On / off toggle ───────────────────────────────────────
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true

                    Label {
                        text: (root.kbdEnabled && root.brightness > 0) ? "On" : "Off"
                        color: "#a6adc8"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: 46; height: 24; radius: 12
                        color: (root.kbdEnabled && root.brightness > 0) ? "#89b4fa" : "#45475a"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var isOn = root.kbdEnabled && root.brightness > 0
                                if (isOn) {
                                    root.kbdEnabled = false
                                } else {
                                    root.kbdEnabled = true
                                    if (root.brightness === 0) root.brightness = 100
                                }
                                root.applyAndSave()
                            }
                        }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: "#1e1e2e"
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.kbdEnabled && root.brightness > 0) ? 25 : 3
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                    }
                }
            }
        }
    }
}
