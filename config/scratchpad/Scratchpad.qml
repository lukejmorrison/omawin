import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "rob.scratchpad"

  function scratchpadWorkspace() {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].name === "special:scratchpad") return values[i]
    }
    return null
  }

  readonly property var workspace: scratchpadWorkspace()
  readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0

  function toggle() {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote('hl.dsp.workspace.toggle_special("scratchpad")'))
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "S"
    opacity: root.occupied ? 1 : 0.5
    tooltipText: "Scratchpad"
    active: root.occupied
    horizontalMargin: 6
    verticalPadding: 6
    onPressed: function() { root.toggle() }
  }
}
