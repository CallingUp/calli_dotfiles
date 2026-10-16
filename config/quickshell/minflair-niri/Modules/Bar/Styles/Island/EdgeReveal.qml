import QtQuick

// Event-driven reveal state. No polling or idle animation.
Item {
    id: controller
    visible: false
    property bool allowed: true
    property bool pinned: false
    property bool hovered: false
    property bool holdOpen: false
    property bool keyboardHold: false
    property bool animationsEnabled: true
    property int enterDelay: 80
    property int leaveDelay: 260
    property bool peek: false
    property bool blocked: false
    readonly property bool requested: allowed && !blocked && (pinned || peek || holdOpen)
    property real progress: requested ? 1 : 0
    signal dismissRequested()

    function hideNow() {
        enterTimer.stop();
        leaveTimer.stop();
        peek = false;
        blocked = true;
    }
    function revealNow() {
        blocked = false;
        peek = true;
        leaveTimer.restart();
    }
    function scheduleLeave() {
        if (!hovered && !pinned && !keyboardHold && (peek || holdOpen))
            leaveTimer.restart();
    }
    onHoveredChanged: {
        if (hovered && allowed) {
            blocked = false;
            leaveTimer.stop();
            enterTimer.restart();
        } else {
            enterTimer.stop();
            scheduleLeave();
        }
    }
    onAllowedChanged: {
        if (!allowed) {
            enterTimer.stop();
            leaveTimer.stop();
            peek = false;
        } else if (hovered) {
            blocked = false;
            enterTimer.restart();
        }
    }
    onPinnedChanged: {
        if (pinned) {
            blocked = false;
            leaveTimer.stop();
        } else scheduleLeave();
    }
    onHoldOpenChanged: scheduleLeave()
    onKeyboardHoldChanged: {
        if (keyboardHold) leaveTimer.stop();
        else scheduleLeave();
    }
    Timer {
        id: enterTimer
        interval: controller.enterDelay
        onTriggered: if (controller.allowed && controller.hovered && !controller.blocked) controller.peek = true
    }
    Timer {
        id: leaveTimer
        interval: controller.leaveDelay
        onTriggered: {
            if (controller.hovered || controller.pinned || controller.keyboardHold) return;
            controller.peek = false;
            controller.dismissRequested();
        }
    }
    Behavior on progress {
        enabled: controller.animationsEnabled
        NumberAnimation {
            duration: controller.requested ? 160 : 90
            easing.type: controller.requested ? Easing.OutCubic : Easing.InQuad
        }
    }
}
