import QtQuick
import qs.Ui

// Omarchy bar widget for the Task Manager.
// Click: toggles the Task Manager window via omarchy-task-manager-toggle
// (launch if absent; hide to special:taskmanager or show from it).
//
// Hit-area constraint: BarIconButton must NOT use anchors.fill: parent.
// In Qt Quick, implicitWidth does NOT automatically propagate to width for
// items loaded inside an anchors-filled Loader; the loaded item's actual
// width can be inflated by the Loader's own size if no explicit width
// binding is present.  Omarchy's Bar.qml moduleClickTargetAt() hit-tests
// ALL registered click targets (global clickTargets[]) whenever any bar
// slot is clicked, using target.width for the boundary check.  An
// oversized button.width causes that hit-test to pass for clicks far
// outside TM's slot, making every bar click appear to toggle TM.
//
// Fix: bind root.width and root.height directly to the button's implicit
// size (= Style.bar.iconSlot) and let the button size itself from its own
// implicitWidth/implicitHeight rather than from the parent.  The click
// target registered in clickTargets[] is then always exactly one icon-slot
// wide, regardless of Loader/ModuleSlot sizing transients.
BarWidget {
  id: root
  moduleName: "sw.art.task-manager"
  // Explicitly constrain actual size to the icon-slot dimensions so the
  // registered click target in Bar.qml's clickTargets[] is always bounded
  // correctly.  Without these bindings the loaded item's width defaults to
  // whatever the Loader provides, which can exceed implicitWidth.
  width: button.implicitWidth
  height: button.implicitHeight
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    // Do NOT use anchors.fill: parent here.  Filling the parent would
    // inherit any inflated parent width and expand the click target beyond
    // the icon slot.  The button sizes itself from fixedWidth: slotSize
    // (Style.bar.iconSlot) via WidgetButton.implicitWidth, which is always
    // the correct fixed slot width.
    bar: root.bar
    text: "󰓅"
    tooltipText: "Task Manager"
    onPressed: function(b) {
      if (b !== Qt.RightButton && root.bar) root.bar.run("omarchy-task-manager-toggle")
    }
  }
}
