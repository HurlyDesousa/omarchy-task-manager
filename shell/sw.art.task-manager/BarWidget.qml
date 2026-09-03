import QtQuick
import qs.Ui

// Omarchy bar widget for the Task Manager.
// Click: toggles the Task Manager window via omarchy-task-manager-toggle
// (launch if absent; hide to special:taskmanager or show from it).
BarWidget {
  id: root
  moduleName: "sw.art.task-manager"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓅"
    tooltipText: "Task Manager"
    onPressed: function(b) {
      if (b !== Qt.RightButton && root.bar) root.bar.run("omarchy-task-manager-toggle")
    }
  }
}
