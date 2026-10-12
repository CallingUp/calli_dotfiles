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
    property bool isScanning: wifiScanProc.running
    property var wifiList: []
    property string connectedSsid: "Disconnected"
    property string currentSsid: {
        if (!isActive)
            return "Off";

        return connectedSsid;
    }
    property bool isVisible: true
    property string operationError: ""
    property string passwordSsid: ""
    property string passwordSecurity: ""
    property string pendingSecret: ""
    readonly property bool connecting: wifiConnectProc.running

    function clearPassword() {
        passwordSsid = "";
        passwordSecurity = "";
        pendingSecret = "";
    }

    function submitPassword(password) {
        if (!password || connecting) return;
        pendingSecret = JSON.stringify({password: password, security: passwordSecurity});
        operationError = "";
        wifiConnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "connect-private", passwordSsid];
        wifiConnectProc.running = true;
    }

    function toggle() {
        wifiSetProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "toggle-radio"];
        wifiSetProc.running = true;
    }

    function scan(forceRescan) {
        if (!root.isActive)
            return ;

        let rescan = (forceRescan === undefined) ? true : forceRescan;
        wifiScanProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "scan", rescan ? "yes" : "no"];
        wifiScanProc.running = false;
        wifiScanProc.running = true;
    }

    function connect(ssid) {
        if (wifiConnectProc.running) return;
        operationError = "";
        const network = wifiList.find(item => item.ssid === ssid);
        if (network && !network.saved && network.security && network.security !== "--") {
            passwordSsid = ssid;
            passwordSecurity = network.security;
            return;
        }
        wifiConnectProc.command = ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "connect", ssid];
        wifiConnectProc.running = true;
    }

    hasMenu: true
    icon: root.isActive ? "wifi" : "wifi-off"
    label: "Wi-Fi"
    subtitle: operationError || (wifiConnectProc.running ? "Conectando…" : root.currentSsid)
    onClicked: root.toggle()
    onExpandedChanged: {
        if (expanded)
            scan(true);

    }
    onIsActiveChanged: {
        if (isActive) {
            scan(false);
            if (expanded)
                scan(true);

        } else {
            wifiList = [];
            connectedSsid = "Disconnected";
        }
    }
    onIsVisibleChanged: {
        if (!isVisible) clearPassword();
        if (isVisible && isActive && root.wifiList.length === 0)
            scan(false);

    }
    Component.onCompleted: {
        if (isActive && root.wifiList.length === 0)
            scan(false);

    }

    Timer {
        interval: 2000
        running: root.isVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wifiGetProc.running = true;
        }
    }

    Process {
        id: wifiGetProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "status"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let st = JSON.parse(data.trim());
                    root.isActive = st.radio;
                    root.connectedSsid = st.connected_ssid || "Disconnected";
                } catch (e) {
                }
            }
        }

    }

    Process {
        id: wifiSetProc

        onRunningChanged: {
            if (!running)
                wifiGetProc.running = true;

        }
    }

    Process {
        id: wifiScanProc

        command: ["python3", Quickshell.shellDir + "/Modules/ControlCenter/scripts/wifi.py", "scan"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return ;

                try {
                    let list = JSON.parse(data.trim());
                    if (Array.isArray(list))
                        root.wifiList = list;

                } catch (e) {
                }
            }
        }

    }

    Process {
        id: wifiConnectProc
        stdinEnabled: true
        onStarted: {
            if (root.pendingSecret) write(root.pendingSecret + "\n");
            root.pendingSecret = "";
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.success) root.operationError = result.output || "No se pudo conectar";
                    else root.clearPassword();
                } catch (error) { root.operationError = "No se pudo conectar"; }
            }
        }

        onRunningChanged: {
            if (!running) {
                wifiGetProc.running = true;
                root.scan(true);
            }
        }
    }


}
