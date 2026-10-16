import QtQuick
import Quickshell
import Quickshell.Io
import qs.Core.Services
pragma Singleton

Item {
    id: displayProfileService

    property bool nightLightActive: false
    property int nightLightTemperature: 4500
    property bool caffeineActive: false
    property bool gameModeActive: false
    property bool gameModeDaemonDetected: false
    property bool autoActivatedByDaemon: false
    property string nightLightError: ""
    property string caffeineError: ""
    property string gameModeError: ""
    property bool updatingState: false
    property bool caffeineBeforeGame: false
    readonly property bool gameModeBusy: gameModePwrProc.running
    readonly property string gameModeSubtitle: {
        if (gameModeError) return gameModeError;
        if (gameModePwrProc.running) return "Aplicando…";
        if (!gameModeActive)
            return "Off";

        if (gameModeDaemonDetected)
            return "Playing (gamemoded)";

        return "Perfil de rendimiento";
    }

    function applyNightLight(state) {
        nightLightError = "";
        if (state) {
            nightLightProc.command = ["gammastep", "-m", "wayland", "-O", displayProfileService.nightLightTemperature.toString()];
            nightLightProc.running = false;
            nightLightProc.running = true;
        } else {
            nightLightProc.running = false;
        }
    }

    function applyCaffeine(state) {
        caffeineError = "";
        caffeineProc.running = state;

    }

    function applyGameMode(enable) {
        if (gameModePwrProc.running) return;
        gameModeError = "";
        if (enable) caffeineBeforeGame = caffeineActive;
        gameModePwrProc.command = ["python3", Quickshell.shellDir + "/Core/Services/scripts/game_mode.py", enable ? "apply" : "revert"];
        gameModePwrProc.running = false;
        gameModePwrProc.running = true;
        displayProfileService.caffeineActive = enable ? true : caffeineBeforeGame;
        // Niri effects and animations are deliberately left untouched.
    }

    Component.onCompleted: {
        if (gameModeActive)
            applyGameMode(true);

    }
    onNightLightActiveChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

        if (!updatingState) applyNightLight(nightLightActive);
    }
    onNightLightTemperatureChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

        if (nightLightActive)
            applyNightLight(true);

    }
    onCaffeineActiveChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

        if (!updatingState) applyCaffeine(caffeineActive);
    }
    onGameModeActiveChanged: {
        if (SettingsService.settingsLoaded)
            SettingsService.saveSettings();

        if (!updatingState) applyGameMode(gameModeActive);
    }

    function updateGameDaemon(active) {
        gameModeDaemonDetected = active;
        if (active && !gameModeActive && !gameModeError) {
            autoActivatedByDaemon = true;
            gameModeActive = true;
        } else if (!active && gameModeActive && autoActivatedByDaemon) {
            autoActivatedByDaemon = false;
            gameModeActive = false;
        }
    }
    property bool gameStatusPending: false
    function refreshGameDaemon() {
        gameStatusPending = true;
        gameStatusDebounce.restart();
    }
    Timer {
        id: gameStatusDebounce
        interval: 50
        onTriggered: {
            if (!checkGameDaemonProc.running && displayProfileService.gameStatusPending) {
                displayProfileService.gameStatusPending = false;
                checkGameDaemonProc.running = true;
            }
        }
    }
    Process {
        id: gameDaemonEvents
        command: ["gdbus", "monitor", "--session", "--dest", "com.feralinteractive.GameMode", "--object-path", "/com/feralinteractive/GameMode"]
        running: true
        onStarted: displayProfileService.refreshGameDaemon()
        onExited: gameMonitorReconnect.restart()
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("does not have an owner")) displayProfileService.updateGameDaemon(false);
                else if (data.includes("GameRegistered") || data.includes("GameUnregistered") || data.includes("PropertiesChanged") || data.includes("owned by")) displayProfileService.refreshGameDaemon();
            }
        }
    }
    Timer {
        id: gameMonitorReconnect
        interval: 3000
        onTriggered: if (!gameDaemonEvents.running) gameDaemonEvents.running = true
    }

    Process {
        id: checkGameDaemonProc

        command: ["gdbus", "call", "--session", "--dest", "com.feralinteractive.GameMode", "--object-path", "/com/feralinteractive/GameMode", "--method", "org.freedesktop.DBus.Properties.Get", "com.feralinteractive.GameMode", "ClientCount"]
        onExited: code => {
            if (code !== 0) displayProfileService.updateGameDaemon(false);
            if (displayProfileService.gameStatusPending) gameStatusDebounce.restart();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const count = text.match(/<(?:int32\s+)?(\d+)>/);
                if (count) displayProfileService.updateGameDaemon(Number(count[1]) > 0);
            }
        }

    }

    Process {
        id: gameModePwrProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.success === false) {
                        displayProfileService.gameModeError = result.output;
                        displayProfileService.updatingState = true;
                        displayProfileService.gameModeActive = !displayProfileService.gameModeActive;
                        displayProfileService.updatingState = false;
                        displayProfileService.caffeineActive = displayProfileService.caffeineBeforeGame;
                    }
                } catch (error) { displayProfileService.gameModeError = "No se pudo comprobar el cambio"; }
            }
        }
    }

    Process {
        id: nightLightProc
        onExited: (code, status) => {
            if (status === 0 && code !== 0 && displayProfileService.nightLightActive) {
                displayProfileService.nightLightError = "No se pudo activar";
                displayProfileService.updatingState = true;
                displayProfileService.nightLightActive = false;
                displayProfileService.updatingState = false;
            }
        }
    }

    Process {
        id: caffeineProc

        command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Keep screen active", "--mode=block", "sleep", "infinity"]
        onExited: (code, status) => {
            if (status === 0 && displayProfileService.caffeineActive) {
                displayProfileService.caffeineError = "Inhibidor no disponible";
                displayProfileService.updatingState = true;
                displayProfileService.caffeineActive = false;
                displayProfileService.updatingState = false;
            }
        }
    }

}
