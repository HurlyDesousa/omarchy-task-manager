// Omarchy bar widget: keyboard RGB backlight control.
// Drives /usr/local/bin/x1e-ec-tool kb '#rrggbb' (solid color, ASUS Vivobook x1e).
//
// State file (Omarchy idle-helper contract):
//   ~/.local/state/omarchy/kbd-backlight
//   JSON: {"hex":"#rrggbb","enabled":true,"autostart":true,"auto_off":true,...}
//   Written atomically (mktemp + rename) on every change AND on startup apply.
//
//   Fields read by external helpers:
//     hex      — actual colour currently sent to EC (for idle restore)
//     enabled  — whether keyboard backlight is on (kbdEnabled && brightness > 0)
//     auto_off — when true, IdleMonitor sends kb #000000 on idle (keyboard only;
//                screen dim at 3 min runs regardless of this flag)
//     autostart— when true, restore last colour/brightness/enabled on session start
//
// Panel pattern: Panel (qs.Ui) + KeyboardPanel (qs.Ui) anchored to the bar button.
// This is the same architecture as omarchy.agents / omarchy.weather and avoids
// the QtQuick.Controls Popup which is clipped by the layer-shell PanelWindow.

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Ui

Panel {
    id: root
    moduleName: "sw.art.kbd-backlight"
    manageIpc: false

    // ── Live state ──────────────────────────────────────────────────────────
    // baseHex: full-brightness chosen color (#rrggbb).
    // brightness: 0–100; scales RGB channels of baseHex linearly.
    // kbdEnabled: explicit off toggle.
    // actualHex: computed color sent to EC and written as "hex" in state file.
    property string  baseHex:    "#ffffff"
    property int     brightness: 100
    property bool    kbdEnabled: true

    // ── Settings state ──────────────────────────────────────────────────────
    // autostart: restore last color/brightness/enabled on session/bar start.
    // autoOff:   IdleMonitor may dim keyboard on idle when true (written as auto_off).
    // showSettings: controls whether gear panel is open in the KeyboardPanel.
    property bool autostart:    true
    property bool autoOff:      true
    property bool showSettings: false

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
                    // Restore base colour for the UI.
                    // _base is the pre-scaled colour; fall back to hex (actualHex at save time).
                    var col = (d._base && /^#[0-9a-fA-F]{6}$/.test(d._base))
                        ? d._base.toLowerCase()
                        : ((d.hex && /^#[0-9a-fA-F]{6}$/.test(d.hex))
                            ? d.hex.toLowerCase() : null)
                    if (col) root.baseHex = col

                    if (typeof d.brightness === "number")
                        root.brightness = Math.max(0, Math.min(100, Math.round(d.brightness)))

                    if (typeof d.enabled === "boolean")
                        root.kbdEnabled = d.enabled

                    if (typeof d.autostart === "boolean")
                        root.autostart = d.autostart

                    if (typeof d.auto_off === "boolean")
                        root.autoOff = d.auto_off
                } catch(e) {}
            }
        }
        onRunningChanged: {
            if (!running) {
                // Only apply to the EC if autostart is enabled.
                if (root.autostart) root._doApply()
                // Always write the canonical prefs file (normalises any old format).
                root._doSave()
            }
        }
    }

    Component.onCompleted: {
        initProc.command = ["/bin/bash", "-c",
            "cat \"$HOME/.local/state/omarchy/kbd-backlight\" 2>/dev/null" +
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

    // Writes the canonical prefs file atomically.
    // Fields:
    //   hex      — actualHex (exact colour sent to EC; idle-helper restore target)
    //   enabled  — whether backlight is effectively on
    //   _base    — pre-scaled base colour (for UI restore across sessions)
    //   brightness — 0-100 (for UI restore)
    //   autostart  — restore on session start (Omarchy / bar restart)
    //   auto_off   — allow IdleMonitor to dim keyboard on idle
    function _doSave() {
        if (saveProc.running) { saveTimer.restart(); return }
        var en = kbdEnabled && brightness > 0
        var payload = '{"hex":"' + actualHex + '"' +
                      ',"enabled":' + (en ? "true" : "false") +
                      ',"_base":"' + baseHex.toLowerCase() + '"' +
                      ',"brightness":' + brightness +
                      ',"autostart":' + (autostart ? "true" : "false") +
                      ',"auto_off":' + (autoOff ? "true" : "false") + '}'
        saveProc.command = ["/bin/bash", "-c",
            "d=\"$HOME/.local/state/omarchy\";" +
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
        // Use root.toggle() so the KeyboardPanel (layer-shell) opens/closes via
        // Panel.panelController — not a QtQuick.Controls Popup.
        onPressed: function(b) {
            if (b !== Qt.RightButton) {
                // Reset settings view on close so next open starts on main panel.
                if (root.opened) root.showSettings = false
                root.toggle()
            }
        }
    }

    // ── Panel ───────────────────────────────────────────────────────────────
    // KeyboardPanel is a layer-shell surface anchored to the bar button.
    KeyboardPanel {
        id: kbdPanel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        contentWidth: 272
        contentHeight: panelContent.implicitHeight

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            border.color: "#45475a"
            border.width: 1
            radius: 8
            clip: true

            ColumnLayout {
                id: panelContent
                spacing: 0
                width: parent.width

                // ── Header row: title + Enabled toggle + gear ─────────────
                RowLayout {
                    spacing: 8
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    Layout.rightMargin: 8
                    Layout.bottomMargin: 8

                    Label {
                        text: "Keyboard Backlight"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#cdd6f4"
                        Layout.fillWidth: true
                    }

                    SettingToggle {
                        compact: true
                        labelText: "Enabled"
                        checked: root.kbdEnabled && root.brightness > 0
                        toggleHandler: function(v) {
                            if (v) {
                                root.kbdEnabled = true
                                if (root.brightness === 0) root.brightness = 100
                            } else {
                                root.kbdEnabled = false
                            }
                            root.applyAndSave()
                        }
                    }

                    // Settings gear button — matches Omarchy themed treatment.
                    Rectangle {
                        id: gearBtn
                        width: 26; height: 26; radius: 5
                        color: root.showSettings ? "#313244" : "transparent"

                        Behavior on color { ColorAnimation { duration: 100 } }

                        Label {
                            anchors.centerIn: parent
                            // nf-md-cog (Material Design cog icon)
                            text: "󰒓"
                            font.pixelSize: 15
                            color: root.showSettings ? "#89b4fa" : "#6c7086"

                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showSettings = !root.showSettings
                        }
                    }
                }

                Rectangle { height: 1; color: "#45475a"; Layout.fillWidth: true }

                // ── Main controls (shown when showSettings is false) ───────
                ColumnLayout {
                    id: mainControls
                    visible: !root.showSettings
                    spacing: 10
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.bottomMargin: 14

                    // ── Colour presets ────────────────────────────────────
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
                                        if (!root.kbdEnabled) root.kbdEnabled = true
                                        if (root.brightness === 0) root.brightness = 100
                                        root.applyAndSave()
                                    }
                                }
                            }
                        }
                    }

                    // ── Brightness slider ─────────────────────────────────
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
                }

                // ── Settings panel (shown when showSettings is true) ───────
                ColumnLayout {
                    id: settingsControls
                    visible: root.showSettings
                    spacing: 10
                    Layout.topMargin: 12
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.bottomMargin: 14

                    // ── Hex color input ───────────────────────────────────
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

                        // Live color preview swatch.
                        Rectangle {
                            width: 22; height: 22; radius: 4
                            color: root.actualHex
                            border.color: "#45475a"; border.width: 1
                        }
                    }

                    Rectangle { height: 1; color: "#313244"; Layout.fillWidth: true }

                    // ── Autostart toggle ──────────────────────────────────
                    // When on: restore last color/brightness/enabled on session/bar start.
                    SettingToggle {
                        labelText: "Autostart"
                        detailText: "Restore on session / bar start"
                        checked: root.autostart
                        toggleHandler: function(v) {
                            root.autostart = v
                            saveTimer.restart()
                        }
                    }

                    // ── Auto-off toggle ───────────────────────────────────
                    // When on: IdleMonitor sends kb #000000 on 3-min idle.
                    // Screen dim runs regardless — this flag is keyboard-only.
                    SettingToggle {
                        labelText: "Auto-off on idle"
                        detailText: "Turn off keyboard (not screen) on 3 min idle"
                        checked: root.autoOff
                        toggleHandler: function(v) {
                            root.autoOff = v
                            saveTimer.restart()
                        }
                    }
                }
            }
        }
    }

    component SettingToggle: RowLayout {
        property string labelText
        property string detailText: ""
        property bool checked
        property var toggleHandler
        property bool compact: false
        Layout.fillWidth: !compact
        spacing: compact ? 6 : 8

        ColumnLayout {
            Layout.fillWidth: !compact
            spacing: 2

            Label {
                text: labelText
                color: "#cdd6f4"
                font.pixelSize: compact ? 11 : 12
            }
            Label {
                visible: detailText !== ""
                text: detailText
                color: "#6c7086"
                font.pixelSize: 10
            }
        }

        Rectangle {
            width: 46; height: 24; radius: 12
            color: checked ? "#89b4fa" : "#45475a"

            Behavior on color { ColorAnimation { duration: 120 } }

            Rectangle {
                width: 18; height: 18; radius: 9
                color: "#1e1e2e"
                anchors.verticalCenter: parent.verticalCenter
                x: checked ? parent.width - width - 3 : 3
                Behavior on x { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (toggleHandler) toggleHandler(!checked)
            }
        }
    }
}
