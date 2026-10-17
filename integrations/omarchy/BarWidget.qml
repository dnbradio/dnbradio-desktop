import QtQuick
import Quickshell
import qs.Ui
import qs.Ui as ShellUi
import qs.Commons

ShellUi.BarWidget {
  id: root
  moduleName: "com.dnbradio.radio"
  property var shell: null
  readonly property var radio: shell ? shell.serviceFor(moduleName) : (bar && bar.shell ? bar.shell.serviceFor(moduleName) : null)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing : false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { if (panelLoader.item) panelLoader.item.open(); }
  function close() { if (panelLoader.item) panelLoader.item.close(); }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle(); }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }
  function injectPanel() {
    if (!panelLoader.item) return;
    panelLoader.item.bar = root.bar;
    panelLoader.item.anchorItem = button;
    panelLoader.item.hostWidget = root;
    panelLoader.item.radio = root.radio;
  }
  onBarChanged: injectPanel()
  onRadioChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
  }
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "󰎆" : (root.radio && root.radio.playing ? "󰎆 " + (root.radio.mode === "archive" ? "DNB Mix" : root.radio.station.name) : "󰎆 DNB")
    active: root.radio ? root.radio.playing : false
    activeColor: Color.accent
    tooltipText: root.radio ? root.radio.title + "\n" + root.radio.artist + "\nLeft: open · Right: play/pause · Scroll: volume" : "DNBRADIO"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle();
      else if (root.radio) root.radio.toggle();
    }
    onWheelMoved: function(delta) {
      if (root.radio) root.radio.volume = Math.max(0, Math.min(1, root.radio.volume + (delta > 0 ? 0.05 : -0.05)));
    }
  }
}
