import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

QuickSettingsTile {
    id: root

    property bool expanded: false
    property bool isScanning: btDiscoveryProc.running
    property var btList: []
    property bool isVisible: true
    property string operationError: ""
    property string pairingName: ""
    property string pairingKind: ""
    property string pairingCode: ""
    readonly property bool pairing: pairingProc.running

    function answerPairing(accept, value) {
        pairingProc.write(JSON.stringify({accept: accept, value: value || ""}) + "\n");
    }
    function cancelPairing() {
        if (pairingProc.running) pairingProc.write('{"cancel":true}\n');
        pairingKind = "";
        pairingCode = "";
    }

    function toggle() {
        btSetProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "toggle-power"];
        btSetProc.running = true;
    }

    function scan() {
        if (!root.isActive)
            return ;

        btDiscoveryProc.running = false;
        btDiscoveryProc.running = true;
    }

    function connect(mac) {
        if (btConnectProc.running || pairingProc.running) return;
        operationError = "";
        const device = btList.find(item => item.mac === mac);
        if (device && !device.paired && !device.connected) {
            pairingName = device.name;
            pairingKind = "";
            pairingCode = "";
            pairingProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth_pair.py", mac];
            pairingProc.running = true;
            return;
        }
        btConnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "toggle-connect", mac];
        btConnectProc.running = true;
    }

    hasMenu: true
    icon: root.isActive ? "bluetooth" : "bluetooth-off"
    label: "Bluetooth"
    subtitle: {
        if (root.operationError) return root.operationError;
        if (pairingProc.running) return "Emparejando…";
        if (btConnectProc.running) return "Conectando…";
        if (!isActive)
            return "Off";

        for (let i = 0; i < btList.length; i++) {
            if (btList[i].connected)
                return btList[i].name;

        }
        return "Disconnected";
    }
    onClicked: root.toggle()
    onExpandedChanged: {
        if (expanded)
            scan();
        else {
            btDiscoveryProc.running = false;
            cancelPairing();
        }
    }
    onIsActiveChanged: {
        if (!isActive) {
            expanded = false;
            btDiscoveryProc.running = false;
            btList = [];
        } else {
            btGetProc.running = false;
            btGetProc.running = true;
        }
    }
    onIsVisibleChanged: {
        if (!isVisible) cancelPairing();
        if (isVisible && isActive) {
            btGetProc.running = false;
            btGetProc.running = true;
        }
    }
    Component.onCompleted: {
        if (isActive) {
            btGetProc.running = false;
            btGetProc.running = true;
        }
    }

    Timer {
        id: updateTimer

        interval: 2500
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            btGetProc.running = true;
        }
    }

    Process {
        id: btGetProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "status"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let parsed = JSON.parse(data);
                    root.isActive = parsed.powered;
                    if (!btDiscoveryProc.running || root.btList.length === 0) {
                        let devs = (parsed.devices || []).slice();
                        if (devs.length > 0 || !root.isScanning)
                            root.btList = devs;

                    }
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: btSetProc

        onRunningChanged: {
            if (!running)
                btGetProc.running = true;

        }
    }

    Process {
        id: btDiscoveryProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/bluetooth.py", "scan"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let parsed = JSON.parse(data);
                    if (parsed.event === "devices")
                        root.btList = (parsed.devices || []).slice();

                } catch (e) {
                }
            }
        }

    }

    Process {
        id: btConnectProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.success) root.operationError = result.output || "No se pudo conectar";
                } catch (error) { root.operationError = "No se pudo conectar"; }
            }
        }

        onRunningChanged: {
            if (!running)
                btGetProc.running = true;

        }
    }

    Process {
        id: pairingProc
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    if (result.event === "prompt") {
                        root.operationError = "";
                        root.pairingKind = result.kind;
                        root.pairingCode = result.code || "";
                    } else if (result.event === "waiting") {
                        root.pairingKind = "";
                        root.pairingCode = "";
                    } else if (result.event === "validation") {
                        root.operationError = result.output;
                    } else if (result.event === "result") {
                        root.operationError = result.success ? "" : result.output;
                        root.pairingKind = "";
                        root.pairingCode = "";
                    }
                } catch (error) { root.operationError = "Respuesta Bluetooth no válida"; }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.pairingKind = "";
            root.pairingCode = "";
            root.pairingName = "";
            if (exitCode !== 0 && !root.operationError) root.operationError = "El emparejamiento se interrumpió";
            btGetProc.running = true;
        }
    }

}
