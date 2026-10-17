import QtQuick
import QtQuick.Controls as Controls

Controls.ScrollView {
  id: root
  objectName: "smooth-scroll-view"
  clip: true
  contentWidth: availableWidth
  readonly property var viewport: contentItem
  property real releaseVelocity: 0
  property double lastInput: 0
  property bool pixelGesture: false
  property bool nativeMomentum: false

  Component.onCompleted: {
    viewport.boundsBehavior = Flickable.StopAtBounds;
    viewport.flickDeceleration = 2600;
    viewport.maximumFlickVelocity = 3000;
  }
  function bounded(value) {
    return Math.max(viewport.originY, Math.min(value, viewport.originY + Math.max(0, viewport.contentHeight - viewport.height)));
  }
  function stopMotion() {
    wheelAnimation.stop();
    viewport.cancelFlick();
  }
  function finishGesture() {
    // WheelHandler ends on ScrollEnd, or after its timeout on devices without
    // phases. A native momentum sequence already owns its release animation.
    if (pixelGesture && !nativeMomentum && Date.now() - lastInput < 140 && Math.abs(releaseVelocity) > 100)
      viewport.flick(0, releaseVelocity);
    releaseVelocity = 0;
  }
  WheelHandler {
    parent: root.viewport
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    activeTimeout: 0.08
    onActiveChanged: {
      if (active) {
        root.stopMotion();
        root.releaseVelocity = 0;
        root.lastInput = 0;
        root.nativeMomentum = false;
      } else root.finishGesture();
    }
    onWheel: function(event) {
      if (event.phase === Qt.ScrollBegin) {
        root.stopMotion();
        root.releaseVelocity = 0;
        root.lastInput = 0;
        root.nativeMomentum = false;
      }
      if (event.phase === Qt.ScrollMomentum) root.nativeMomentum = true;
      var pixels = event.pixelDelta.y;
      var angle = event.angleDelta.y;
      if (!pixels && !angle) return;
      event.accepted = true;
      var now = Date.now();
      if (pixels) {
        root.stopMotion();
        var elapsed = now - root.lastInput;
        var speed = Math.max(-3000, Math.min(3000, pixels * 1000 / Math.max(8, elapsed)));
        root.releaseVelocity = root.lastInput && elapsed < 120
          ? (speed * root.releaseVelocity < 0 ? speed : root.releaseVelocity * 0.35 + speed * 0.65) : 0;
        root.viewport.contentY = root.bounded(root.viewport.contentY - pixels);
        root.pixelGesture = true;
      } else {
        // Ordinary wheel notches get a short eased movement, without a fling.
        var previousTarget = wheelAnimation.running ? wheelAnimation.to : root.viewport.contentY;
        root.stopMotion();
        root.pixelGesture = false;
        root.releaseVelocity = 0;
        wheelAnimation.from = root.viewport.contentY;
        wheelAnimation.to = root.bounded(previousTarget - angle / 120 * 80);
        wheelAnimation.start();
      }
      root.lastInput = now;
    }
  }
  NumberAnimation {
    id: wheelAnimation
    target: root.viewport; property: "contentY"
    duration: 140; easing.type: Easing.OutCubic
  }
  TapHandler {
    parent: root.viewport
    onPressedChanged: if (pressed) { root.stopMotion(); root.releaseVelocity = 0; }
  }
  Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
  Controls.ScrollBar.vertical: Controls.ScrollBar {
    onPressedChanged: if (pressed) { root.stopMotion(); root.releaseVelocity = 0; }
  }
}
