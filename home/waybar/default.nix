{
  pkgs,
  lib,
  config,
  hostProfile ? { },
  ...
}:
let
  isLaptop = hostProfile.isLaptop or false;
  waybarSettings = {
    layer = "top";
    position = "top";
    height = 26;
    spacing = 6;
    "margin-top" = 4;
    "margin-left" = 8;
    "margin-right" = 8;

    "modules-left" = [
      "custom/logo"
      "cpu"
      "memory"
      "disk"
    ];
    "modules-center" = [ "hyprland/workspaces" ];
    "modules-right" = [
      "mpris"
      "pulseaudio"
      "bluetooth"
      "custom/idle"
    ]
    ++ lib.optionals isLaptop [ "custom/battery" ]
    ++ [
      "clock"
      "custom/notifications"
      "tray"
    ];

    "custom/logo" = {
      format = "❄";
      on-click = "rofi-freq";
      tooltip = false;
    };

    cpu = {
      format = "🧠 {usage}%";
      interval = 5;
      tooltip = true;
    };

    memory = {
      format = "💾 {percentage}%";
      interval = 5;
      tooltip-format = "{used:0.1f}G / {total:0.1f}G";
    };

    disk = {
      format = "🗄 {percentage_used}%";
      interval = 30;
      path = "/";
      tooltip-format = "{used} / {total} on {path}";
    };

    "hyprland/workspaces" = {
      "all-outputs" = true;
      format = "{name}";
      on-click = "activate";
      "sort-by-number" = true;
    };

    "custom/notifications" = {
      escape = true;
      exec = "swaync-client -swb";
      format = "💬  {}";
      on-click = "swaync-client -t -sw";
      on-click-right = "swaync-client -d -sw";
      "return-type" = "json";
    };

    "custom/idle" = {
      exec = "idle-control status";
      interval = 5;
      on-click = "idle-control toggle";
      "return-type" = "json";
      signal = 8;
    };

    mpris = {
      player = "playerctld";
      format = "🎵 {artist} - {title}";
      format-paused = "⏸ {artist} - {title}";
      format-stopped = "";
      artist-len = 24;
      title-len = 36;
      dynamic-len = 54;
      tooltip-format = "{player} ({status})\n{artist} - {title}\n{album}";
    };

    network = {
      format = "{ifname}";
      format-disconnected = "󰤮 offline";
      format-ethernet = "󰈀 connected";
      format-linked = "󰈀 no ip";
      format-wifi = "󰤨 {essid}";
      tooltip-format = "{ifname}: {ipaddr}/{cidr}\n{bandwidthUpBits} ↑  {bandwidthDownBits} ↓";
      tooltip-format-disconnected = "No network connection";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-bluetooth = "🎧 {volume}%";
      format-icons = {
        default = [
          "🔈"
          "🔉"
          "🔊"
        ];
        headphone = "🎧";
        headset = "🎧";
      };
      format-muted = "🔇";
      on-click = "pavucontrol";
    };

    bluetooth = {
      format = "";
      "format-disabled" = "";
      "format-connected" = " {device_alias}";
      "format-connected-battery" = " {device_alias} {device_battery_percentage}%";
      "tooltip-format" = "{controller_alias}\t{controller_address}";
      "tooltip-format-connected" = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
      "tooltip-format-enumerate-connected" = "{device_alias}\t{device_address}";
      on-click = "blueman-manager";
    };

    "custom/battery" = {
      exec = "battery-estimate";
      interval = 15;
      "return-type" = "json";
      tooltip = true;
    };

    clock = {
      format = "🕐 {:%a, %d %b, %I:%M %p}";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    };

    tray = {
      "icon-size" = 16;
      spacing = 8;
    };
  };
  waybarStyle = ''
    * {
      font-family: "Maple Mono NL NF", "Noto Color Emoji";
      font-size: 12px;
      font-weight: 500;
      min-height: 0;
      border: none;
      border-radius: 0;
      padding: 0;
      margin: 0;
    }

    window#waybar {
      background: transparent;
      color: #cdd6f4;
    }

    #custom-logo,
    #workspaces,
    #cpu,
    #memory,
    #disk,
    #network,
    #pulseaudio,
    #bluetooth,
    #custom-battery,
    #custom-notifications,
    #custom-idle,
    #mpris,
    #clock,
    #tray {
      background: rgba(17, 17, 27, 0.85);
      color: #cdd6f4;
      padding: 1px 10px;
      border-radius: 999px;
      margin: 0 2px;
    }

    #custom-logo {
      color: #89b4fa;
      font-size: 16px;
      padding: 4px 14px;
    }

    #workspaces {
      padding: 3px 6px;
    }
    #workspaces button {
      color: #cdd6f4;
      background: transparent;
      padding: 0 10px;
      margin: 0 2px;
      border-radius: 999px;
      min-width: 22px;
      transition: all 200ms ease;
    }
    #workspaces button:hover {
      background: rgba(137, 180, 250, 0.15);
      box-shadow: none;
      text-shadow: none;
    }
    #workspaces button.active {
      background: rgba(137, 180, 250, 0.25);
      color: #cdd6f4;
      padding: 0 14px;
    }
    #workspaces button.urgent {
      background: rgba(243, 139, 168, 0.4);
      color: #1e1e2e;
    }

    #network.disconnected { color: #f38ba8; }
    #bluetooth.disabled { color: #6c7086; }
    #bluetooth.connected { color: #89b4fa; }
    #pulseaudio.muted { color: #6c7086; }
    #custom-battery.warning { color: #f9e2af; }
    #custom-battery.critical { color: #f38ba8; }
    #custom-battery.charging { color: #a6e3a1; }

    #custom-notifications { padding: 1px 10px; color: #cdd6f4; }
    #custom-notifications.dnd { color: #6c7086; }

    #custom-idle.enabled { color: #89b4fa; }
    #custom-idle.inhibited { color: #f9e2af; }

    #mpris.paused { color: #6c7086; }
    #mpris.stopped { opacity: 0; padding: 0; margin: 0; }

    #tray { padding: 4px 10px; }
    #tray > .passive { -gtk-icon-effect: dim; }
  '';
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = false;
    settings = [ ];
    style = null;
  };

  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar";
      PartOf = [ "hyprland-session.target" ];
      After = [ "hyprland-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      ExecReload = "${pkgs.procps}/bin/pkill -u $USER -USR2 waybar";
      ExecStop = "${pkgs.procps}/bin/pkill -u $USER -x waybar";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install.WantedBy = [ "hyprland-session.target" ];
  };

  xdg.configFile."waybar/config" = {
    text = builtins.toJSON [ waybarSettings ];
    onChange = ''
      systemctl --user reload waybar.service || systemctl --user restart waybar.service || true
    '';
  };

  xdg.configFile."waybar/style.css" = {
    text = waybarStyle;
    onChange = ''
      systemctl --user reload waybar.service || systemctl --user restart waybar.service || true
    '';
  };
}
