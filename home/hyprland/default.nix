{
  pkgs,
  lib,
  config,
  repoRoot,
  hostProfile ? { },
  ...
}:
let
  isLaptop = hostProfile.isLaptop or false;
  hasWireless = hostProfile.hasWireless or false;
  swapAltSuper = hostProfile.swapAltSuper or true;
  hypridle = {
    lockTimeout = 300;
    dpmsTimeout = 330;
    suspendTimeout = null;
    suspendRequiresNoSsh = false;
  }
  // (hostProfile.hypridle or { });
  monitorConfig =
    if isLaptop then
      "eDP-1,preferred,auto,1"
    else
      ",preferred,auto,1";
  kbOptionsLine = lib.optionalString swapAltSuper "      kb_options = altwin:swap_lalt_lwin\n";
  wirelessAutostartLine = lib.optionalString hasWireless "    exec-once = nm-applet --indicator\n";
  hyprlandConfigText = ''
    exec-once = dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user stop hyprland-session.target && systemctl --user start hyprland-session.target

    $browser = zen-beta
    $menu = rofi-freq
    $mod = SUPER
    $term = foot

    animations {
      bezier = subtle, 0.16, 1, 0.3, 1
      animation = windows, 1, 5, subtle
      animation = windowsOut, 1, 5, subtle, slide
      animation = border, 1, 6, subtle
      animation = fade, 1, 6, subtle
      animation = workspaces, 1, 5, subtle, fade
      enabled = true
    }

    cursor {
      no_hardware_cursors = true
    }

    decoration {
      active_opacity = 1.0
      inactive_opacity = 1.0

      blur {
        enabled = true
        size = 6
        passes = 3
        ignore_opacity = true
      }

      shadow {
        color = rgba(00000066)
        color_inactive = rgba(00000022)
        enabled = true
        range = 18
        render_power = 3
      }

      rounding = 8
    }

    general {
      border_size = 2
      col.active_border = rgba(cba6f755)
      col.inactive_border = rgba(00000000)
      gaps_in = 5
      gaps_out = 10
      layout = dwindle
    }

    input {
      scroll_factor = 0.6
      emulate_discrete_scroll = 1

      touchpad {
        disable_while_typing = false
        natural_scroll = false
        scroll_factor = 0.7
      }

      # DBeaver/Eclipse SWT dialogs can close when Hyprland moves focus on hover.
      # Keep focus click-driven so modal dialogs do not lose focus just because
      # the pointer crosses back to the parent window.
      follow_mouse = 0
      float_switch_override_focus = 0
      mouse_refocus = 0
      kb_layout = us
${kbOptionsLine}      repeat_delay = 250
      repeat_rate = 40
    }

    bind = $mod, T, exec, $term
    bind = $mod, B, exec, $browser
    bind = $mod SHIFT, B, exec, edit-bookmarks
    bind = $mod, E, exec, thunar
    bind = $mod, Q, killactive,
    bind = $mod, M, exec, rofi-bookmarks
    bind = $mod SHIFT, M, exec, edit-bookmarks
    bind = $mod, Space, exec, $menu
    bind = $mod, Escape, exec, loginctl lock-session
    bind = $mod, F, fullscreen,
    bind = $mod, V, exec, clipboard-selector
    bind = $mod, N, exec, agent-notify --open-latest
    bind = $mod SHIFT, V, togglefloating,
    bind = $mod, H, movefocus, l
    bind = $mod, L, movefocus, r
    bind = $mod, K, movefocus, u
    bind = $mod, J, movefocus, d
    bind = $mod, 1, workspace, 1
    bind = $mod, 2, workspace, 2
    bind = $mod, 3, workspace, 3
    bind = $mod, 4, workspace, 4
    bind = $mod, 5, workspace, 5
    bind = $mod SHIFT, 1, movetoworkspace, 1
    bind = $mod SHIFT, 2, movetoworkspace, 2
    bind = $mod SHIFT, 3, movetoworkspace, 3
    bind = $mod SHIFT, 4, movetoworkspace, 4
    bind = $mod SHIFT, 5, movetoworkspace, 5
    bind = $mod, 6, workspace, 6
    bind = $mod, 7, workspace, 7
    bind = $mod, 8, workspace, 8
    bind = $mod, 9, workspace, 9
    bind = $mod SHIFT, 6, movetoworkspace, 6
    bind = $mod SHIFT, 7, movetoworkspace, 7
    bind = $mod SHIFT, 8, movetoworkspace, 8
    bind = $mod SHIFT, 9, movetoworkspace, 9
    bind = $mod SHIFT, BackSpace, exec, waypaper
    bind = $mod SHIFT, P, exec, grim -g "$(slurp -d)" - | swappy -f -
    bind = $mod SHIFT, R, exec, wf-record
    bind = $mod SHIFT, T, exec, wf-record-region
    bind = $mod SHIFT, I, exec, idle-control toggle
    bind = $mod SHIFT, U, exec, transcribe toggle
    bind = $mod SHIFT, l, exec, kill -35 $(pgrep -fo nwg-dock)

    bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindel = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindel = , F8, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , F7, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindel = , F6, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

    env = XCURSOR_THEME,capitaine-cursors
    env = XCURSOR_SIZE,24

    exec-once = [workspace 1 silent] foot
    exec-once = [workspace 2 silent] zen-beta
    exec-once = [workspace 5 silent] bitwarden
    exec-once = [workspace 8 silent] obsidian
    exec-once = wl-paste --watch cliphist store
${wirelessAutostartLine}    exec-once = nwg-dock-hyprland -p bottom -lp end -i 36 -c rofi-freq -r
    exec-once = swaync
    exec-once = blueman-applet
    exec-once = swww-daemon

    monitor = ${monitorConfig}

    windowrulev2 = float, class:^(waypaper)$
    windowrulev2 = size 900 600, class:^(waypaper)$
    windowrulev2 = center, class:^(waypaper)$
    windowrulev2 = animation fade, class:^(waypaper)$
    windowrulev2 = opacity 0.7 0.7, class:^(waypaper)$
    windowrulev2 = float, class:^(bookmark-editor)$
    windowrulev2 = center, class:^(bookmark-editor)$
  '';
  reloadHyprland = ''
    (
      XDG_RUNTIME_DIR=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
      if [[ -d "/tmp/hypr" || -d "$XDG_RUNTIME_DIR/hypr" ]]; then
        mapfile -t instances < <(${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl instances -j | jq ".[].instance" -r)

        for i in "''${instances[@]}"; do
          ${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl -i "$i" reload config-only
        done

        if [[ "''${#instances[@]}" -gt 0 ]]; then
          systemctl --user restart waybar.service || true
        fi
      fi
    )
  '';
  idleControl = pkgs.writeShellScriptBin "idle-control" ''
    set -euo pipefail

    service="hypridle.service"

    is_active() {
      ${pkgs.systemd}/bin/systemctl --user is-active --quiet "$service"
    }

    print_status() {
      if is_active; then
        text="💤 idle"
        class="enabled"
        tooltip=$'Idle enabled\nLock, screen-off, and suspend timers can run.\nClick or press Super+Shift+I to keep awake.'
      else
        text="☕ awake"
        class="inhibited"
        tooltip=$'Idle disabled\nThis computer will stay awake until idle is re-enabled.\nClick or press Super+Shift+I to allow idle again.'
      fi

      ${pkgs.jq}/bin/jq -cn \
        --arg text "$text" \
        --arg class "$class" \
        --arg tooltip "$tooltip" \
        '{ text: $text, class: $class, tooltip: $tooltip }'
    }

    refresh_waybar() {
      ${pkgs.procps}/bin/pkill -RTMIN+8 waybar 2>/dev/null || true
    }

    case "''${1:-status}" in
      status)
        print_status
        ;;
      toggle)
        if is_active; then
          ${pkgs.systemd}/bin/systemctl --user stop "$service"
          ${config.wayland.windowManager.hyprland.finalPackage}/bin/hyprctl dispatch dpms on >/dev/null 2>&1 || true
          ${pkgs.libnotify}/bin/notify-send "Idle disabled" "This computer will stay awake." || true
        else
          ${pkgs.systemd}/bin/systemctl --user start "$service"
          ${pkgs.libnotify}/bin/notify-send "Idle enabled" "Lock, screen-off, and suspend timers are active." || true
        fi
        refresh_waybar
        print_status
        ;;
      *)
        echo "Usage: idle-control [status|toggle]" >&2
        exit 2
        ;;
    esac
  '';
  suspendIfNoSsh = pkgs.writeShellScriptBin "suspend-if-no-ssh" ''
    set -euo pipefail

    has_ssh_session=0
    while read -r session_id _; do
      [[ -n "$session_id" ]] || continue
      session_props="$(${pkgs.systemd}/bin/loginctl show-session "$session_id" -p Remote -p Service --no-pager 2>/dev/null || true)"
      if grep -qx 'Remote=yes' <<< "$session_props" || grep -qx 'Service=sshd' <<< "$session_props"; then
        has_ssh_session=1
        break
      fi
    done < <(${pkgs.systemd}/bin/loginctl list-sessions --no-legend 2>/dev/null || true)

    if [[ "$has_ssh_session" -eq 1 ]]; then
      ${pkgs.systemd}/bin/systemd-cat -t hypridle-suspend-if-no-ssh echo "Skipping idle suspend: SSH session active"
      exit 0
    fi

    ${pkgs.systemd}/bin/systemctl suspend
  '';
  suspendCommand =
    if hypridle.suspendRequiresNoSsh then
      "${suspendIfNoSsh}/bin/suspend-if-no-ssh"
    else
      "systemctl suspend";
in
{
  home.packages = with pkgs; [
    hyprlock
    idleControl
  ];

  xdg.configFile."hypr/hyprlock.conf" = {
    text = builtins.readFile ./hyprlock.conf;
  };

  xdg.configFile."hypr/hyprland.conf" = lib.mkForce {
    text = hyprlandConfigText;
    onChange = reloadHyprland;
  };

  services.hyprsunset = {
    enable = true;
    systemdTarget = "hyprland-session.target";
    settings = {
      profile = [
        {
          time = "7:30";
          identity = true;
        }
        {
          time = "19:00";
          temperature = 5000;
        }
        {
          time = "21:00";
          temperature = 3800;
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          timeout = hypridle.lockTimeout;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = hypridle.dpmsTimeout;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ]
      ++ lib.optionals (hypridle.suspendTimeout != null) [
        {
          timeout = hypridle.suspendTimeout;
          on-timeout = suspendCommand;
        }
      ];
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;

    # Keep Home Manager's Hyprland session wiring enabled while the actual
    # config file is generated here.
    extraConfig = "# managed via xdg.configFile.\"hypr/hyprland.conf\"";
  };
}
