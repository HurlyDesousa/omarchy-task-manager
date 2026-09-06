import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Weather / Task Manager bar-widget pattern: Loader → Panel.qml, injectPanel, togglePanel.
// Hit area constrained to icon slot (no anchors.fill on BarIconButton).
// Popup is pinned to the right screen edge (not centered on the bar).
BarWidget {
    id: root
    moduleName: "sw.art.ai-usage"

    function pinRightAnchor() {
        var win = button.QsWindow ? button.QsWindow.window : null
        if (!win || !win.contentItem)
            return
        if (rightEdgeAnchor.parent !== win.contentItem)
            rightEdgeAnchor.parent = win.contentItem
        rightEdgeAnchor.anchors.right = win.contentItem.right
        rightEdgeAnchor.anchors.top = win.contentItem.top
    }

    function injectPanel() {
        var target = panelLoader.item
        if (!target) return
        root.pinRightAnchor()
        if ("bar" in target) target.bar = root.bar
        if ("settings" in target) target.settings = root.settings
        if ("anchorItem" in target) target.anchorItem = rightEdgeAnchor
        if ("hostWidget" in target) target.hostWidget = root
    }

    function togglePanel() {
        if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root, direction)
        return false
    }

    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

    function open() {
        if (panelLoader.item && panelLoader.item.openFromHotkey)
            panelLoader.item.openFromHotkey()
    }

    function close() {
        if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
    }

    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true : false

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    width: button.implicitWidth
    height: button.implicitHeight
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    Item {
        id: rightEdgeAnchor
        width: 1
        height: 1
        visible: false
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    BarIconButton {
        id: button
        bar: root.bar
        text: "󰚩"
        tooltipText: "AI usage (Cursor, Grok Bot, Grok build)"
        onPressed: function(b) {
            if (b !== Qt.RightButton) {
                if (root.opened && panelLoader.item) panelLoader.item.showSettings = false
                root.togglePanel()
            }
        }
        onWidthChanged: root.pinRightAnchor()
        Component.onCompleted: Qt.callLater(root.pinRightAnchor)
    }
}
