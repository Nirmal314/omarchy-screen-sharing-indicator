import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
BarWidget {
  id: root
  moduleName: "archer-nemo.screen-sharing"
  property bool sharing: false
  property string sourceApp: ""
  readonly property string scriptPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/archer-nemo.screen-sharing/bin/screen-sharing.sh"
  function refresh() {
    if (!root.bar || statusProc.running) return
    statusProc.running = true
  }
  onBarChanged: refresh()
  Component.onCompleted: {
    refresh()
    pollTimer.start()
  }
  visible: sharing
  implicitWidth: 16
  implicitHeight: barSize
  readonly property bool tooltipHovered: visible && hoverArea.containsMouse
  Timer {
    id: pollTimer
    interval: Math.max(1000, (root.setting("pollSeconds", 3) || 3) * 1000)
    repeat: true
    running: false
    onTriggered: root.refresh()
  }
  Process {
    id: statusProc
    command: [root.scriptPath]
    stdout: SplitParser {
      onRead: function(line) {
        var trimmed = String(line || "").trim()
        if (trimmed === "") return
        try {
          var data = JSON.parse(trimmed)
          root.sharing = data.sharing === true
          root.sourceApp = data.source || ""
        } catch (e) {
          root.sharing = false
          root.sourceApp = ""
        }
      }
    }
  }
  Rectangle {
    id: pulseRing
    width: 9
    height: 9
    radius: 4.5
    anchors.centerIn: parent
    color: "#ff2222"
    opacity: 0
    scale: 1.0
    visible: root.sharing
    SequentialAnimation on scale {
      running: root.sharing
      loops: Animation.Infinite
      NumberAnimation { from: 1.0; to: 2.5; duration: 1500; easing.type: Easing.OutCubic }
    }
    SequentialAnimation on opacity {
      running: root.sharing
      loops: Animation.Infinite
      NumberAnimation { from: 0.75; to: 0.75; duration: 0 }
      NumberAnimation { from: 0.75; to: 0.0; duration: 1500; easing.type: Easing.OutCubic }
    }
  }
  // Static core dot: stays fully opaque red, fixed size.
  Rectangle {
    id: dot
    width: 9
    height: 9
    radius: 4.5
    anchors.centerIn: parent
    color: "#ff2222"
    opacity: 1.0
    z: 1
  }
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.ArrowCursor
    onEntered: function() {
      var tip = "Screen Shared"
      if (root.sourceApp) tip += " (" + root.sourceApp + ")"
      if (root.bar) root.bar.showTooltip(root, tip)
    }
    onExited: function() {
      if (root.bar) root.bar.hideTooltip(root)
    }
  }
}
