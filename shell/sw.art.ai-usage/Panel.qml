// AI Usage panel — Cursor Pro+ / Grok Bot / Grok build quota bars.
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

    function limitPercent(limit) {
        if (!limit) return null
        var p = Number(limit.percent)
        if (!isFinite(p)) return null
        if (p > 1) p = p / 100
        return Math.max(0, Math.min(1, p))
    }

    function percentLabel(limit) {
        var p = limitPercent(limit)
        return p === null ? root.emDash : Math.round(p * 100) + "% used"
    }

    function statusLine(agent) {
        if (!agent) return "No data yet"
        if (agent.authHelpText) return agent.authHelpText
        if (agent.usageStatusText) return agent.usageStatusText
        return agent.available ? "" : "No data yet"
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
        contentWidth: panel.fittedContentWidth(Style.space(440))
        contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(520))

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
                        spacing: Style.space(14)

                        CursorUsageSection {
                            width: parent.width
                            agent: root.agentById("cursor")
                            bar: root.bar
                            emDash: root.emDash
                            percentLabel: root.percentLabel
                            limitPercent: root.limitPercent
                            statusLine: root.statusLine(root.agentById("cursor"))
                        }

                        GrokBotUsageSection {
                            width: parent.width
                            agent: root.agentById("grokbot")
                            bar: root.bar
                            emDash: root.emDash
                            percentLabel: root.percentLabel
                            limitPercent: root.limitPercent
                            statusLine: root.statusLine(root.agentById("grokbot"))
                        }

                        GrokBuildUsageSection {
                            width: parent.width
                            agent: root.agentById("grok")
                            bar: root.bar
                            emDash: root.emDash
                            percentLabel: root.percentLabel
                            limitPercent: root.limitPercent
                            statusLine: root.statusLine(root.agentById("grok"))
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
                            text: "Version 0.5.5-28"
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
        property string barStyle: "accent"
        property var bar
        height: Style.space(6)

        readonly property color trackColor: Qt.rgba(
            bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.14
        )
        readonly property color fillColor: barStyle === "muted"
            ? Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.42)
            : Color.accent

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.trackColor
            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, fraction))
                radius: parent.radius
                color: parent.parent.fillColor
            }
        }
    }

    component UsageMeterRow: Column {
        id: row
        property var limit
        property var bar
        property var percentLabel
        property var limitPercent

        spacing: Style.space(4)
        width: parent.width

        readonly property string rowTitle: limit ? (limit.label || limit.title || "Usage") : ""
        readonly property string rowCaption: {
            if (!limit) return ""
            if (limit.caption) return limit.caption
            if (limit.resetCaption) return limit.resetCaption
            return ""
        }

        RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Label {
                text: row.rowTitle
                color: bar.foreground
                font.family: bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: limit ? percentLabel(limit) : ""
                color: Qt.darker(bar.foreground, 1.15)
                font.family: bar.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
            }
        }

        MeterBar {
            width: parent.width
            fraction: limit ? (limitPercent(limit) || 0) : 0
            barStyle: limit && limit.barStyle ? limit.barStyle : "accent"
            bar: row.bar
        }

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: rowCaption !== ""
            text: rowCaption
            color: Qt.darker(bar.foreground, 1.45)
            font.family: bar.fontFamily
            font.pixelSize: Style.font.caption
        }
    }

    component DarkUsageCard: Rectangle {
        id: card
        property var limits
        property var bar
        property var percentLabel
        property var limitPercent
        property string statusLine: ""
        property bool showMeters: true

        radius: Style.cornerRadius
        color: Qt.rgba(0, 0, 0, 0.28)
        border.color: Qt.rgba(bar.foreground.r, bar.foreground.g, bar.foreground.b, 0.08)
        border.width: Style.spacing.hairline
        implicitWidth: parent ? parent.width : 0
        implicitHeight: cardColumn.implicitHeight + Style.space(24)

        Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(12)
            spacing: Style.space(10)

            Repeater {
                model: card.showMeters ? (card.limits || []) : []
                delegate: UsageMeterRow {
                    required property var modelData
                    width: parent.width
                    limit: modelData
                    bar: card.bar
                    percentLabel: card.percentLabel
                    limitPercent: card.limitPercent
                }
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: card.statusLine !== "" && (!card.showMeters || !(card.limits || []).length)
                text: card.statusLine
                color: Qt.darker(card.bar.foreground, 1.4)
                font.family: card.bar.fontFamily
                font.pixelSize: Style.font.caption
            }
        }
    }

    component CursorUsageSection: Column {
        property var agent
        property var bar
        property string emDash
        property var percentLabel
        property var limitPercent
        property string statusLine: ""

        spacing: Style.space(6)
        width: parent.width

        Label {
            text: "Cursor"
            font.pixelSize: Style.font.body
            font.bold: true
            color: bar.foreground
            font.family: bar.fontFamily
        }

        DarkUsageCard {
            width: parent.width
            bar: parent.bar
            limits: agent ? (agent.limits || []) : []
            percentLabel: parent.percentLabel
            limitPercent: parent.limitPercent
            statusLine: parent.statusLine
            showMeters: agent && (agent.limits || []).length > 0
        }
    }

    component GrokBotUsageSection: Column {
        property var agent
        property var bar
        property string emDash
        property var percentLabel
        property var limitPercent
        property string statusLine: ""

        spacing: Style.space(6)
        width: parent.width

        Label {
            text: "Grok Bot"
            font.pixelSize: Style.font.body
            font.bold: true
            color: bar.foreground
            font.family: bar.fontFamily
        }

        DarkUsageCard {
            width: parent.width
            bar: parent.bar
            limits: agent ? (agent.limits || []) : []
            percentLabel: parent.percentLabel
            limitPercent: parent.limitPercent
            statusLine: parent.statusLine
            showMeters: agent && (agent.limits || []).length > 0
        }
    }

    component GrokBuildUsageSection: Column {
        property var agent
        property var bar
        property string emDash
        property var percentLabel
        property var limitPercent
        property string statusLine: ""

        spacing: Style.space(6)
        width: parent.width

        Label {
            text: agent ? (agent.name || "Grok (grok build)") : "Grok (grok build)"
            font.pixelSize: Style.font.body
            font.bold: true
            color: bar.foreground
            font.family: bar.fontFamily
        }

        DarkUsageCard {
            width: parent.width
            bar: parent.bar
            limits: agent ? (agent.limits || []) : []
            percentLabel: parent.percentLabel
            limitPercent: parent.limitPercent
            statusLine: parent.statusLine
            showMeters: agent && (agent.limits || []).length > 0
        }
    }
}
