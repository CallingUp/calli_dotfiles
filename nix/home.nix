{ config, lib, pkgs, ... }:
let
  cfg = config.programs.hakuShell;
  source = import ./source.nix { inherit lib; };
  runtime = import ./runtime.nix { inherit pkgs; };
  tools = import ./tools.nix { inherit pkgs; };
  python = lib.last runtime;
  names = [ "haku-lock" "haku-waybar-visibility" "haku-clipboard" "haku-clipboard-worker"
    "haku-connectivity-worker" "haku-info-worker" "haku-theme-worker" "haku-wallpaper-worker"
    "haku-wallpaper-selector" "wallpaper-carousel" "haku-shortcuts" "haku-qml-menu"
    "haku-osd-control" "get_accent_color.py" ];
  wrap = name:
    let text = builtins.readFile (../scripts/bin + "/${name}");
        interpreter = if lib.hasPrefix "#!/usr/bin/env python3" text
          then "${python}/bin/python3" else "${pkgs.bash}/bin/bash";
    in pkgs.writeShellScriptBin name ''
      exec ${interpreter} ${source}/scripts/bin/${name} "$@"
    '';
  scripts = pkgs.symlinkJoin {
    name = "haku-scripts";
    paths = map wrap names ++ [
      (pkgs.writeShellScriptBin "awww" ''exec ${pkgs.swww}/bin/swww "$@"'')
      (pkgs.writeShellScriptBin "awww-daemon" ''exec ${pkgs.swww}/bin/swww-daemon "$@"'')
      (pkgs.writeShellScriptBin "set-wallpaper" ''exec ${pkgs.bash}/bin/bash ${source}/installer/set-wallpaper "$@"'')
      (pkgs.writeShellScriptBin "haku-wallpaper-restore" ''exec ${pkgs.bash}/bin/bash ${source}/installer/wallpaper-restore "$@"'')
      (pkgs.writeShellScriptBin "wallpaper-transition" ''exec ${pkgs.bash}/bin/bash ${source}/installer/wallpaper-transition "$@"'')
      (pkgs.writeShellScriptBin "wallpaper-theme-sync" ''exec ${pkgs.bash}/bin/bash ${source}/installer/wallpaper-theme-sync "$@"'')
    ];
  };
  portable = lib.replaceStrings [ "@HOME@" "@KEYBOARD@" ]
    [ config.home.homeDirectory cfg.keyboardLayout ] (builtins.readFile ../installer/niri-portable.kdl);
in {
  options.programs.hakuShell = {
    enable = lib.mkEnableOption "Haku QuickShell with portable Niri configuration";
    keyboardLayout = lib.mkOption { type = lib.types.str; default = "us"; };
    installNiriConfig = lib.mkOption { type = lib.types.bool; default = true; description = "Set false to keep an existing Niri configuration."; };
  };
  config = lib.mkIf cfg.enable {
    assertions = [{ assertion = lib.versionAtLeast pkgs.qt6.qtbase.version "6.9";
      message = "Haku requiere Qt >= 6.9 para RectangularShadow."; }];
    home.packages = runtime ++ [ tools scripts ];
    # Existing runtimes expect this path. Home Manager refuses conflicting files.
    home.file = {
      "haku_shell".source = source;
      "Pictures/Wallpapers/.keep".text = "";
      ".local/state/haku_theme/colors.css".text = ''
        @define-color accent_color #B99573;
        @define-color accent_active #D7B894;
        @define-color accent_inactive #705542;
      '';
    } // builtins.listToAttrs (map (name: {
      name = ".local/bin/${name}";
      value.source = "${scripts}/bin/${name}";
    }) (names ++ [ "awww" "awww-daemon" "set-wallpaper" "haku-wallpaper-restore" "wallpaper-transition" "wallpaper-theme-sync" ]));
    xdg.configFile = {
      "haku/palette.conf".source = ../config/haku/palette.conf;
      "haku/palette.css".source = ../config/haku/palette.css;
    } // lib.optionalAttrs cfg.installNiriConfig { "niri/config.kdl".text = portable; };
    systemd.user.services.haku-quickshell = {
      Unit = { Description = "Haku QuickShell"; PartOf = [ "graphical-session.target" ]; After = [ "graphical-session.target" ]; };
      Service = {
        ExecStart = "${pkgs.quickshell}/bin/quickshell -p ${source}/config/quickshell/minflair-niri/niri-preview.qml";
        Environment = [ "PATH=${lib.makeBinPath ([ scripts tools ] ++ runtime)}" "HAKU_PACKAGE_BACKEND=disabled"
          "QML2_IMPORT_PATH=${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" ];
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
