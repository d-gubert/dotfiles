import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.active-window"


  readonly property var toplevel: ToplevelManager.activeToplevel
  // LOCAL CHANGE: the bar shows the app, not the window title. A title like
  // "README.md - dotfiles" does not say which app runs. The built-in widget
  // reads the title first and falls back to the app id; this reverses that and
  // shortens the app id. The tooltip still carries the full window title.
  readonly property string label: appLabel(toplevel ? toplevel.appId : "", title)
  readonly property string title: toplevel ? (toplevel.title || "") : ""
  readonly property int maxLabelWidth: Number(setting("maxWidth", 280))

  // Turn a Wayland app id into something short enough for the bar.
  //
  //   org.wezfurlong.wezterm         -> wezterm
  //   chrome-web.whatsapp.com__-Def. -> web.whatsapp.com
  //   Alacritty                      -> Alacritty
  //
  // Chromium names a --app= window "chrome-<encoded url>-Default" and encodes
  // every "/" of the url as "_". Omarchy launches every web app that way, so
  // the host is what identifies one. A Chrome extension app has no host in
  // that position, and the window title names it instead.
  function appLabel(appId, windowTitle) {
    if (!appId) return windowTitle || ""

    var webapp = /^chrome-(.+)-Default$/.exec(appId)
    if (webapp) {
      var host = webapp[1].split("_")[0]
      return host.indexOf(".") !== -1 ? host : (windowTitle || appId)
    }

    // A reverse-DNS id carries the name in its last segment. Anything with a
    // path separator is not an id of that shape, so leave it alone.
    if (appId.indexOf("/") === -1 && appId.indexOf(".") !== -1) {
      var segments = appId.split(".")
      for (var i = segments.length - 1; i >= 0; i--) {
        if (segments[i]) return segments[i]
      }
    }

    return appId
  }

  visible: label !== "" && !vertical
  implicitWidth: visible ? Math.min(maxLabelWidth, labelText.implicitWidth) + Style.spacing.controlPaddingX * 2 : 0
  implicitHeight: barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Item {
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    clip: true

    Text {
      id: labelText
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      width: parent.width
      text: root.label
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      opacity: 0.85
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (!root.toplevel) return
      if (mouse.button === Qt.MiddleButton) {
        root.toplevel.close()
      } else if (mouse.button === Qt.RightButton) {
        root.toplevel.close()
      } else {
        root.toplevel.activate()
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.title || root.label)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
