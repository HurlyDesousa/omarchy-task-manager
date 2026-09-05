// AI Usage panel — Weather / Task Manager KeyboardPanel pattern.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "sw.art.ai-usage"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root

    property var snapshot: ({ agents: [] })
    property bool updating: false

    readonly property string emDash: "\u2014"
    readonly property int refreshMs: 300000

    function open() {
        root.controller.show()
        updateAndRefresh()
    }

    function openFromHotkey() {
        root.open()
    }

    function close() {
        root.controller.hide()
    }

    function toggle() {
        if (root.opened) root.close()
        else root.openFromHotkey()
    }

    function refresh() {
        if (!usageProc.running) usageProc.running = true
    }

    function updateAndRefresh() {
        if (updateProc.running) return
        root.updating = true
        updateProc.running = true
    }

    function agentById(id) {
        var agents = root.snapshot.agents || []
        for (var i = 0; i < agents.length; i++) {
            if (agents[i].id === id) return agents[i]
        }
        return null
    }

    function formatTokens(value) {
        var n = Number(value)
        if (!isFinite(n) || n <= 0) return root.emDash
        if (n >= 1_000_000) return (n / 1_000_000).toFixed(1) + "M"
        if (n >= 1_000) return (n / 1_000).toFixed(1) + "k"
        return String(Math.round(n))
    }

    function limitPercent(limit) {
        if (!limit) return 0
        var p = Number(limit.percent)
        return isFinite(p) ? Math.max(0, Math.min(1, p)) : 0
    }

    Process {
        id: usageProc
        stdout: SplitParser {
            onRead: function(line) {
                var l = line.trim()
                if (!l) return
                try { root.snapshot = JSON.parse(l) } catch (e) {}
            }
        }
        command: ["omarchy-task-manager", "ai-usage"]
    }

    Process {
        id: updateProc
        onRunningChanged: {
            if (!running) {
                root.updating = false
                root.refresh()
            }
        }
        command: ["omarchy-task-manager", "ai-usage-update"]
    }

    Timer {
        id: refreshTimer
        interval: root.refreshMs
        repeat: true
        running: root.opened
        triggeredOnStart: false
        onTriggered: root.updateAndRefresh()
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: true
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(420))
        contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(480))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                if (root.hostWidget && root.hostWidget.switchPanel)
                    root.hostWidget.switchPanel(direction)
                else if (typeof root.switchPanel === "function")
                    root.switchPanel(direction)
            }

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: mainColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: mainColumn
                    width: flick.width
                    spacing: Style.space(10)

                    RowLayout {
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        spacing: Style.space(8)

                        Label {
                            text: "AI Usage"
                            font.pixelSize: Style.font.title
                            font.bold: true
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: root.updating
                            text: "Updating\u2026"
                            color: Qt.darker(root.bar.foreground, 1.3)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Rectangle {
                            width: 26; height: 26; radius: Style.cornerRadius
                            opacity: root.updating ? 0.5 : 1.0
                            color: Style.hoverFillFor(root.bar.foreground, Color.accent)
                            Label {
                                anchors.centerIn: parent
                                text: "󰑐"
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                color: root.bar.foreground
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.updating
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateAndRefresh()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.spacing.hairline
                        color: root.bar.foreground
                        opacity: 0.12
                    }

                    Column {
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        spacing: Style.space(12)

                        Repeater {
                            model: ["cursor", "codex", "grok"]
                            delegate: AgentUsageCard {
                                required property string modelData
                                width: parent.width
                                agent: root.agentById(modelData)
                                bar: root.bar
                                emDash: root.emDash
                                formatTokens: root.formatTokens
                                limitPercent: root.limitPercent
                            }
                        }

                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: "Local pi is excluded. Refreshes on open from ~/.local/state/omarchy/agents/usage/."
                            color: Qt.darker(root.bar.foreground, 1.5)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Label {
                            text: "Version 0.5.5-25"
                            color: Qt.darker(root.bar.foreground, 1.5)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.bodySmall
                        }
                    }
                }
            }
        }
    }

    component MeterBar: Item {
        property real fraction: 0
        property var bar
        height: Style.space(6)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.darker(bar.foreground, 2.2)
            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, fraction))
                radius: parent.radius
                color: Color.accent
            }
        }
    }

    component AgentUsageCard: Column {
        id: card
        property var agent
        property var bar
        property string emDash
        property var formatTokens
        property var limitPercent

        spacing: Style.space(6)

        readonly property bool available: agent && agent.available === true
        readonly property string displayName: agent ? (agent.name || agent.id) : "\u2014"
        readonly property var limits: agent && agent.limits ? agent.limits : []
        readonly property string statusLine: {
            if (!agent) return "No data yet"
            if (agent.authHelpText) return agent.authHelpText
            if (agent.usageStatusText) return agent.usageStatusText
            return available ? "" : "No data yet"
        }

        Label {
            text: displayName
            font.pixelSize: Style.font.body
            font.bold: true
            color: bar.foreground
            font.family: bar.fontFamily
        }

        RowLayout {
            width: parent.width
            spacing: Style.space(8)
            Label {
                text: "Today"
                color: Qt.darker(card.bar.foreground, 1.4)
                font.family: card.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                Layout.preferredWidth: Style.space(52)
            }
            Label {
                text: available ? formatTokens(agent.todayTotalTokens) + " tok" : emDash
                color: bar.foreground
                font.family: bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                Layout.fillWidth: true
            }
            Label {
                text: available && agent.tierLabel ? agent.tierLabel : ""
                color: Qt.darker(bar.foreground, 1.3)
                font.family: bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                Layout.maximumWidth: Style.space(120)
            }
        }

        Repeater {
            model: card.limits
            delegate: Column {
                required property var modelData
                width: parent.width
                spacing: Style.space(2)
                Label {
                    text: modelData.label || "Limit"
                    color: Qt.darker(card.bar.foreground, 1.4)
                    font.family: card.bar.fontFamily
                    font.pixelSize: Style.font.caption
                }
                MeterBar {
                    width: parent.width
                    fraction: card.limitPercent(modelData)
                    bar: card.bar
                }
            }
        }

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: statusLine !== ""
            text: statusLine
            color: Qt.darker(bar.foreground, 1.4)
            font.family: bar.fontFamily
            font.pixelSize: Style.font.caption
        }

        Rectangle {
            width: parent.width
            height: Style.spacing.hairline
            color: bar.foreground
            opacity: 0.08
        }
    }
}
