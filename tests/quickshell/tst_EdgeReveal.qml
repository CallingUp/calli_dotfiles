import QtQuick
import QtTest
import "../../config/quickshell/minflair-niri/Modules/Bar/Styles/Island" as Bar

TestCase {
    name: "EdgeReveal"
    Bar.EdgeReveal { id: reveal; animationsEnabled: false; enterDelay: 20; leaveDelay: 40 }
    SignalSpy { id: dismiss; target: reveal; signalName: "dismissRequested" }
    function init() {
        reveal.hovered = false;
        reveal.pinned = false;
        reveal.keyboardHold = false;
        reveal.holdOpen = false;
        reveal.hideNow();
        reveal.allowed = true;
        dismiss.clear();
    }
    function test_hover() {
        compare(reveal.requested, false);
        reveal.hovered = true;
        tryCompare(reveal, "progress", 1);
        reveal.hovered = false;
        compare(reveal.requested, true);
        tryCompare(reveal, "progress", 0);
    }
    function test_briefPass() {
        reveal.hovered = true;
        reveal.hovered = false;
        wait(80);
        compare(reveal.requested, false);
    }
    function test_pinAndHide() {
        reveal.pinned = true;
        compare(reveal.progress, 1);
        reveal.hideNow();
        compare(reveal.progress, 0);
        reveal.pinned = false;
    }
    function test_keyboard() {
        reveal.revealNow();
        reveal.keyboardHold = true;
        wait(80);
        compare(reveal.progress, 1);
        reveal.keyboardHold = false;
        tryCompare(reveal, "progress", 0);
    }
    function test_fullscreen() {
        reveal.pinned = true;
        reveal.allowed = false;
        compare(reveal.progress, 0);
        reveal.allowed = true;
        compare(reveal.progress, 1);
    }
    function test_panelDismiss() {
        reveal.revealNow();
        reveal.holdOpen = true;
        tryCompare(dismiss, "count", 1);
        reveal.holdOpen = false;
        compare(reveal.progress, 0);
    }
}
