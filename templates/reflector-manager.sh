#!/bin/bash
# AF0WX Reflector Manager
# Project-specific management layer for EdHasley/Extended_Name_Reflector.
# PP5PK's original user/database manager remains available as option 1.
set -u

# Softer yellow used for manager headings/status labels.
SOFT_YELLOW='\033[38;5;186m'
GREEN='\033[38;5;114m'
RED='\033[38;5;203m'
NC='\033[0m'
yellow(){ echo -e "${SOFT_YELLOW}$*${NC}"; }
status_word(){ [[ "${1:-0}" == "1" ]] && echo "ENABLED" || echo "DISABLED"; }

MAIN_H="/usr/src/xlxd/src/main.h"
SRC_DIR="/usr/src/xlxd/src"
CONF="/etc/extended-name-reflector/reflector.conf"
DASH_CFG="/var/www/html/xlxd/pgs/config.inc.php"
CALLHOME="/xlxd/callinghome.php"
USER_MANAGER="/xlxd/users_db/reflector_user_manager.sh"
BACKUP_DIR="/var/backups/extended-name-reflector"
ACCESS_DIR="/xlxd"

need_root() { if [[ ${EUID:-$(id -u)} -ne 0 ]]; then exec sudo "$0" "$@"; fi; }
pause(){ read -r -p "Press Enter to continue..." _; }
yn(){ local a; read -r -p "$1 [y/N]: " a; [[ "${a^^}" == Y || "${a^^}" == YES ]]; }
port(){ [[ "$1" =~ ^[0-9]+$ ]] && ((1<=10#$1 && 10#$1<=65535)); }
get_define(){ grep -E "^[[:space:]]*#define[[:space:]]+$1[[:space:]]+" "$MAIN_H" 2>/dev/null | tail -1 | awk '{print $3}'; }
set_define(){
  local key="$1" val="$2"
  grep -Eq "^[[:space:]]*#define[[:space:]]+${key}[[:space:]]+" "$MAIN_H" || { echo "Cannot find ${key} in ${MAIN_H}"; return 1; }
  sed -Ei "s|^([[:space:]]*#define[[:space:]]+${key}[[:space:]]+).*|\\1${val}|" "$MAIN_H"
}
toggle_define(){
  local key="$1" label="${2:-$1}" cur ans
  cur=$(get_define "$key"); cur=${cur:-0}
  echo "Current: $label = $(status_word "$cur")"
  read -r -p "E=Enable, D=Disable, X=Back: " ans
  case "${ans^^}" in E) set_define "$key" 1;; D) set_define "$key" 0;; X|'') return 0;; *) echo "Invalid choice."; return 1;; esac
}
port_define(){
  local key="$1" cur ans; cur=$(get_define "$key")
  echo "Current port: ${cur:-unknown}"
  read -r -p "New port (Enter keeps current, X=Back): " ans
  [[ "${ans^^}" == X ]] && return 0
  ans=${ans:-$cur}; port "$ans" || { echo "Invalid port."; return 1; }; set_define "$key" "$ans"
}

rebuild(){
  echo
  echo "This recompiles XLXD and restarts the reflector service."
  yn "Continue" || return
  (cd "$SRC_DIR" && make && make install) || { echo "Build/install failed. Existing service was not deliberately removed."; pause; return; }
  if [[ -x /usr/local/bin/software-ambed ]]; then
    bash /usr/src/xlxd/software-ambed/install.sh "$(get_define TRANSCODER_PORT)" "" --no-start || { echo "Software transcoder rebuild failed."; pause; return; }
    systemctl is-active --quiet software-ambed.service && systemctl restart software-ambed.service
  fi
  if [[ -x /ambed/ambed ]]; then
    (cd /usr/src/xlxd/ambed && make && make install) || { echo "AMBED build failed; check the build output."; pause; return; }
    systemctl is-active --quiet ambed.service && systemctl restart ambed.service
  fi
  if [[ -x /xlxd/xlxecho && -f /usr/src/XLXEcho/xlxecho.c ]]; then
    local interlink_port=$(get_define XLX_PORT)
    sed -Ei "s|^#define XLX_PORT [0-9]+|#define XLX_PORT $interlink_port|" /usr/src/XLXEcho/xlxecho.c
    gcc -o /usr/src/XLXEcho/xlxecho /usr/src/XLXEcho/xlxecho.c || { echo "Echo Test build failed."; pause; return; }
    cp -f /usr/src/XLXEcho/xlxecho /xlxd/xlxecho || { echo "Echo Test install failed."; pause; return; }
    systemctl is-active --quiet xlxecho.service && systemctl restart xlxecho.service
  fi
  systemctl restart xlxd.service || { echo "XLXD restart failed."; pause; return; }
  echo "XLXD rebuilt and restarted."
  pause
}

protocols(){
  while true; do
    clear
    yellow "=== Protocol Enable / Disable ==="
    printf "%-3s %-24s %s\n" "#" "PROTOCOL" "STATUS"
    printf "%-3s %-24s %s\n" "1" "DExtra" "$(status_word "$(get_define ENABLE_DEXTRA)")"
    printf "%-3s %-24s %s\n" "2" "DPlus" "$(status_word "$(get_define ENABLE_DPLUS)")"
    printf "%-3s %-24s %s\n" "3" "DCS" "$(status_word "$(get_define ENABLE_DCS)")"
    printf "%-3s %-24s %s\n" "4" "XLX interlink" "$(status_word "$(get_define ENABLE_XLX)")"
    printf "%-3s %-24s %s\n" "5" "DMRPlus" "$(status_word "$(get_define ENABLE_DMRPLUS)")"
    printf "%-3s %-24s %s\n" "6" "DMR MMDVM" "$(status_word "$(get_define ENABLE_DMRMMDVM)")"
    printf "%-3s %-24s %s\n" "7" "Yaesu / System Fusion" "$(status_word "$(get_define ENABLE_YSF)")"
    printf "%-3s %-24s %s\n" "8" "IMRS" "$(status_word "$(get_define ENABLE_IMRS)")"
    printf "%-3s %-24s %s\n" "9" "G3 Terminal" "$(status_word "$(get_define ENABLE_G3)")"
    echo "X   Back"
    read -r -p "> " c
    case "$c" in
      1) toggle_define ENABLE_DEXTRA "DExtra";; 2) toggle_define ENABLE_DPLUS "DPlus";;
      3) toggle_define ENABLE_DCS "DCS";; 4) toggle_define ENABLE_XLX "XLX interlink";;
      5) toggle_define ENABLE_DMRPLUS "DMRPlus";; 6) toggle_define ENABLE_DMRMMDVM "DMR MMDVM";;
      7) toggle_define ENABLE_YSF "Yaesu / System Fusion";; 8) toggle_define ENABLE_IMRS "IMRS";;
      9) toggle_define ENABLE_G3 "G3 Terminal";; [Xx]) return;;
    esac
  done
}

ports_menu(){
  while true; do
    clear
    yellow "=== Protocol Ports (enabled protocols only) ==="
    local n=1 c key label
    declare -a keys labels
    add_port(){ keys[$n]="$1"; labels[$n]="$2"; printf "%-3s %-24s %s\n" "$n" "$2" "$(get_define "$1")"; ((n++)); }
    [[ "$(get_define ENABLE_DEXTRA)" == 1 ]] && add_port DEXTRA_PORT "DExtra"
    [[ "$(get_define ENABLE_DPLUS)" == 1 ]] && add_port DPLUS_PORT "DPlus"
    [[ "$(get_define ENABLE_DCS)" == 1 ]] && add_port DCS_PORT "DCS"
    add_port JSON_PORT "XLX Core / JSON"
    [[ "$(get_define ENABLE_XLX)" == 1 ]] && add_port XLX_PORT "XLX interlink"
    [[ "$(get_define ENABLE_DMRPLUS)" == 1 ]] && add_port DMRPLUS_PORT "DMRPlus"
    [[ "$(get_define ENABLE_DMRMMDVM)" == 1 ]] && add_port DMRMMDVM_PORT "DMR MMDVM"
    [[ "$(get_define ENABLE_YSF)" == 1 ]] && add_port YSF_PORT "YSF"
    [[ "$(get_define ENABLE_IMRS)" == 1 ]] && add_port IMRS_PORT "IMRS"
    if [[ "$(get_define ENABLE_G3)" == 1 ]]; then
      add_port G3_PRESENCE_PORT "G3 presence"; add_port G3_CONFIG_PORT "G3 config"; add_port G3_DV_PORT "G3 DV"
    fi
    echo "A   AMBE/transcoder"
    echo "X   Back"
    read -r -p "> " c
    [[ "${c^^}" == X ]] && return
    [[ "${c^^}" == A ]] && { ambe_menu; continue; }
    [[ "$c" =~ ^[0-9]+$ && -n "${keys[$c]:-}" ]] && port_define "${keys[$c]}"
  done
}

install_ambe(){
  echo "AMBED requires compatible AMBE hardware to operate."
  [[ -d /usr/src/xlxd/ambed ]] || { echo "Bundled AMBED source is not present at /usr/src/xlxd/ambed."; pause; return; }
  yn "Install AMBED now" || return
  (cd /usr/src/xlxd/ambed && make clean && make && make install) || { echo "AMBED build/install failed."; pause; return; }
  cat > /etc/systemd/system/ambed.service <<'EOF'
[Unit]
Description=AMBED Transcoder
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
ExecStartPre=-/sbin/rmmod ftdi_sio
ExecStartPre=-/sbin/rmmod usbserial
ExecStart=/ambed/ambed 127.0.0.1
User=root
Group=root
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable ambed.service >/dev/null 2>&1 || true
  echo "AMBED installed. Connect compatible AMBE hardware before starting the service."
  pause
}

transcoder_port(){
  local value
  port_define TRANSCODER_PORT || return
  value=$(get_define TRANSCODER_PORT)
  if [[ -f /usr/src/xlxd/ambed/main.h ]]; then
    sed -Ei "s|^(#define[[:space:]]+TRANSCODER_PORT[[:space:]]+).*|\\1$value|" /usr/src/xlxd/ambed/main.h
  fi
  echo "Transcoder port set to $value. Choose Rebuild to apply compiled changes."
  pause
}

ambe_menu(){
  while true; do
    clear
    yellow "=== AMBE / Transcoder ==="
    if [[ -x /usr/local/bin/software-ambed ]]; then
      echo "Software D-Star/DMR backend (experimental)"
      echo "Port: $(get_define TRANSCODER_PORT)"
      echo "1 Change port (then choose Rebuild)"
      echo "2 Enable/disable software service"
      echo "X Back"
      read -r -p "> " c
      case "$c" in
        1) transcoder_port;;
        2) if systemctl is-enabled --quiet software-ambed.service; then systemctl disable --now software-ambed.service; else systemctl enable --now software-ambed.service; fi;;
        [Xx]) return;;
      esac
    elif [[ -x /ambed/ambed ]]; then
      echo "Status: INSTALLED"
      echo "Port:   $(get_define TRANSCODER_PORT)"
      echo "1 Change transcoder port"
      echo "2 Enable/disable AMBED service"
      echo "X Back"
      read -r -p "> " c
      case "$c" in
        1) transcoder_port;;
        2) if systemctl is-enabled --quiet ambed.service 2>/dev/null; then systemctl disable --now ambed.service; else systemctl enable --now ambed.service; fi;;
        [Xx]) return;;
      esac
    else
      echo "Status: NOT INSTALLED"
      echo "Choose hardware AMBED or the experimental chip-free software backend."
      echo "1 Install hardware AMBED"
      echo "2 Install software D-Star/DMR transcoder (experimental)"
      echo "X Back"
      read -r -p "> " c
      case "$c" in
        1) install_ambe;;
        2) bash /usr/src/xlxd/software-ambed/install.sh "$(get_define TRANSCODER_PORT)" || { echo "Software installation failed."; pause; };;
        [Xx]) return;;
      esac
    fi
  done
}

dashboard_settings(){
  local name callhome
  name=$(sed -n 's/^EXTENDED_NAME="\(.*\)"/\1/p' "$CONF" | tail -1)
  callhome=$(sed -n 's/^CALL_HOME="\([YN]\)"/\1/p' "$CONF" | tail -1)
  python3 /usr/local/bin/dashboard-settings.py /var/www/html/xlxd/config.inc.php "$name" "${callhome:-N}"
}

dashboard_menu(){
  local current new
  current=$(sed -n 's/^EXTENDED_NAME="\(.*\)"/\1/p' "$CONF" 2>/dev/null | tail -1)
  echo "Current extended name: ${current:-not set}"
  read -r -p "New extended name (Enter keeps current, X=Back): " new
  [[ "${new^^}" == X || -z "$new" ]] && return
  if [[ ${#new} -lt 1 || ${#new} -gt 60 || "$new" == *\"* || "$new" == *\\* ]]; then
    echo "Extended name must be 1-60 characters and cannot contain double quotes or backslashes."
    pause
    return
  fi
  sed -i "s|^EXTENDED_NAME=.*|EXTENDED_NAME=\"$new\"|" "$CONF"
  dashboard_settings && echo "Extended name set to: $new"
  pause
}

callhome_menu(){
  local current ans
  current=$(sed -n 's/^CALL_HOME="\([YN]\)"/\1/p' "$CONF" 2>/dev/null | tail -1)
  [[ "$current" == Y ]] && echo "Current call-home advertising: ENABLED" || echo "Current call-home advertising: DISABLED"
  read -r -p "E=Enable, D=Disable, X=Back: " ans
  case "${ans^^}" in
    E) ans=Y;;
    D) ans=N;;
    X|'') return;;
    *) echo "Invalid choice."; pause; return;;
  esac
  sed -i "s/^CALL_HOME=.*/CALL_HOME=\"$ans\"/" "$CONF"
  dashboard_settings
  [[ "$ans" == Y ]] && echo "Call-home advertising is now ENABLED." || echo "Call-home advertising is now DISABLED."
  pause
}

header_menu(){
  clear
  echo "=== Optional Dashboard Header ==="
  echo "The original header is preserved before replacement."
  echo "Custom PNG height must match the currently installed header."
  local current="" custom=""
  current=$(find /var/www/html/xlxd -type f -name 'header.png' 2>/dev/null | head -1)
  [[ -n "$current" ]] || { echo "Installed header.png not found."; pause; return; }
  echo "Installed header: $current"
  read -r -p "Full path to custom header.png (Enter cancels): " custom
  [[ -n "$custom" ]] || return
  [[ -f "$custom" ]] || { echo "File not found."; pause; return; }
  file "$custom" | grep -qi 'PNG image' || { echo "The selected file is not a PNG."; pause; return; }
  [[ -f "${current}.original" ]] || cp -p "$current" "${current}.original"
  # PNG IHDR stores width/height at bytes 16..23. Compare height only; width may vary.
  oldh=$(od -An -tu4 -N4 -j20 --endian=big "$current" | tr -d ' ')
  newh=$(od -An -tu4 -N4 -j20 --endian=big "$custom" | tr -d ' ')
  if [[ -z "$oldh" || -z "$newh" || "$oldh" != "$newh" ]]; then
    echo "Header height mismatch. Installed=${oldh:-unknown}px custom=${newh:-unknown}px. No change made."
    pause; return
  fi
  cp "$custom" "$current"
  chmod 644 "$current"
  echo "Custom header installed. Width was allowed to vary; height remained ${oldh}px."
  pause
}

safety_copy(){
  local f="$1" d="$BACKUP_DIR/safety"
  mkdir -p "$d"
  [[ -f "$f" ]] && cp -p "$f" "$d/$(basename "$f").$(date +%Y%m%d-%H%M%S).bak"
}

access_control_menu(){
  local c a f
  while true; do
    clear; yellow "=== Access Control / XLXD Databases ==="
    echo "Each edit creates a timestamped safety copy first."
    echo "1 Whitelist"; echo "2 Blacklist"; echo "3 Interlink"; echo "4 Terminal"; echo "X Back"
    read -r -p "> " c
    [[ "${c^^}" == X ]] && return
    case "$c" in
      1) f="$ACCESS_DIR/xlxd.whitelist";; 2) f="$ACCESS_DIR/xlxd.blacklist";;
      3) f="$ACCESS_DIR/xlxd.interlink";; 4) f="$ACCESS_DIR/xlxd.terminal";; *) continue;;
    esac
    [[ -f "$f" ]] || { echo "File not found: $f"; pause; continue; }
    echo "Current file: $f"; echo "V View   E Edit   X Back"; read -r -p "> " a
    case "${a^^}" in
      V)
        echo "Press Q to exit the viewer and return to the menu."
        less -P 'Press Q to return to the menu | %f | Line %lt' -- "$f"
        ;;
      E) safety_copy "$f"; if command -v nano >/dev/null 2>&1; then nano "$f"; else "${EDITOR:-vi}" "$f"; fi; echo "Saved. Safety copy: $BACKUP_DIR/safety/"; pause;;
    esac
  done
}

backup_config(){
  local stamp out tmp old_lan current_lan public_ip domain
  stamp=$(date +%Y%m%d-%H%M%S); mkdir -p "$BACKUP_DIR"; tmp=$(mktemp -d)
  mkdir -p "$tmp/etc" "$tmp/source" "$tmp/access"
  [[ -f "$CONF" ]] && cp -p "$CONF" "$tmp/etc/reflector.conf"
  [[ -f "$MAIN_H" ]] && cp -p "$MAIN_H" "$tmp/source/main.h"
  for f in xlxd.whitelist xlxd.blacklist xlxd.interlink xlxd.terminal; do [[ -f "$ACCESS_DIR/$f" ]] && cp -p "$ACCESS_DIR/$f" "$tmp/access/$f"; done
  current_lan=$(hostname -I 2>/dev/null | awk '{print $1}'); public_ip=$(curl -m 5 -s https://api4.ipify.org 2>/dev/null || true)
  domain=$(sed -n 's/^XLXDOMAIN_B64="\(.*\)"/\1/p' "$CONF" 2>/dev/null | tail -1 | base64 -d 2>/dev/null || true)
  printf 'BACKUP_VERSION="1"\nLAN_IP="%s"\nPUBLIC_IP="%s"\nDOMAIN="%s"\n' "$current_lan" "$public_ip" "$domain" > "$tmp/network-reference.conf"
  out="$BACKUP_DIR/reflector-backup-$stamp.tar.gz"; tar -C "$tmp" -czf "$out" .; rm -rf "$tmp"; chmod 600 "$out"
  echo "Backup created: $out"; echo "This folder is outside /etc/extended-name-reflector and survives the project uninstaller."; pause
}

restore_config(){
  local src tmp old_ip current_ip
  mkdir -p "$BACKUP_DIR"; echo "Available backups:"
  find "$BACKUP_DIR" -maxdepth 1 -type f -name "reflector-backup-*.tar.gz" -printf "  %p\n" 2>/dev/null | sort -r
  read -r -p "Backup file to restore (full path, Enter cancels): " src; [[ -n "$src" ]] || return
  [[ -f "$src" ]] || { echo "Backup file not found."; pause; return; }; tar -tzf "$src" >/dev/null 2>&1 || { echo "Invalid backup archive."; pause; return; }
  tmp=$(mktemp -d); tar -C "$tmp" -xzf "$src"
  old_ip=$(sed -n 's/^LAN_IP="\(.*\)"/\1/p' "$tmp/network-reference.conf" 2>/dev/null | tail -1); current_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo "Previous VM LAN IP: ${old_ip:-unknown}"; echo "Current VM LAN IP:  ${current_ip:-unknown}"; echo "The restore will KEEP the current VM network configuration."
  read -r -p "Continue restore? [y/N]: " ans; [[ "${ans^^}" == Y || "${ans^^}" == YES ]] || { rm -rf "$tmp"; return; }
  mkdir -p "$BACKUP_DIR/pre-restore"; for f in xlxd.whitelist xlxd.blacklist xlxd.interlink xlxd.terminal; do [[ -f "$ACCESS_DIR/$f" ]] && cp -p "$ACCESS_DIR/$f" "$BACKUP_DIR/pre-restore/$f.$(date +%Y%m%d-%H%M%S).bak"; done
  [[ -f "$CONF" ]] && cp -p "$CONF" "$BACKUP_DIR/pre-restore/reflector.conf.$(date +%Y%m%d-%H%M%S).bak"
  [[ -f "$tmp/etc/reflector.conf" ]] && { mkdir -p "$(dirname "$CONF")"; cp -p "$tmp/etc/reflector.conf" "$CONF"; }
  [[ -f "$tmp/source/main.h" ]] && cp -p "$tmp/source/main.h" "$MAIN_H"
  for f in xlxd.whitelist xlxd.blacklist xlxd.interlink xlxd.terminal; do [[ -f "$tmp/access/$f" ]] && cp -p "$tmp/access/$f" "$ACCESS_DIR/$f"; done
  rm -rf "$tmp"; dashboard_settings || true; echo "Restore complete. Current VM IP was not changed. Rebuild XLXD to apply compiled settings."; pause
}

backup_restore_menu(){
  local c
  while true; do clear; yellow "=== Backup / Restore Reflector Configuration ==="; echo "Backup folder: $BACKUP_DIR"; echo "1 Create portable backup"; echo "2 Restore portable backup"; echo "X Back"; read -r -p "> " c; case "$c" in 1) backup_config;; 2) restore_config;; [Xx]) return;; esac; done
}

maintenance_menu(){
  while true; do
    clear
    yellow "=== XLXD Maintenance ==="
    echo "1 Reinstall/rebuild XLXD from the existing source (preserves reflector configuration)"
    echo "2 Uninstall XLXD core"
    echo "X Back"
    read -r -p "> " c
    case "$c" in
      1) rebuild; return;;
      2)
        echo "This removes the XLXD core/service only. Dashboard, SSL/Certbot, Cloudflared, and AMBED are not deliberately removed."
        read -r -p "Type UNINSTALL to confirm, or X to go back: " ans
        [[ "${ans^^}" == X ]] && return
        [[ "$ans" == UNINSTALL ]] || { echo "Uninstall cancelled."; pause; return; }
        systemctl disable --now xlxd.service 2>/dev/null || true
        rm -f /etc/systemd/system/xlxd.service /xlxd/xlxd
        systemctl daemon-reload
        echo "XLXD core binary/service removed. Configuration and other components were preserved."
        pause
        return
        ;;
      [Xx]) return;;
    esac
  done
}

status_menu(){
  echo "XLXD service: $(systemctl is-active xlxd.service 2>/dev/null || true)"
  echo "Apache:       $(systemctl is-active apache2 2>/dev/null || true)"
  echo "AMBE:         $(systemctl is-active ambed.service 2>/dev/null || echo not-installed)"
  echo "Protocol ID:  $(sed -n 's/^PROTOCOL_ID="\(.*\)"/\1/p' "$CONF" 2>/dev/null | tail -1)"
  echo "Extended name: $(sed -n 's/^EXTENDED_NAME="\(.*\)"/\1/p' "$CONF" 2>/dev/null | tail -1)"
  pause
}

need_root "$@"
while true; do
  clear
  yellow "=============================================="
  yellow "        AF0WX REFLECTOR MANAGER"
  yellow "=============================================="
  echo "1. User / RadioID management"
  echo "2. Enable or disable protocols"
  echo "3. Change protocol ports"
  echo "4. AMBE / transcoder settings"
  echo "5. Extended name / dashboard text"
  echo "6. Public call-home advertising"
  echo "7. Rebuild XLXD and restart reflector"
  echo "8. XLXD uninstall / reinstall maintenance"
  echo "9. Show service / reflector status"
  echo "10. Access control: whitelist / blacklist / interlink / terminal"
  echo "11. Backup / restore reflector configuration"
  echo "X. Exit"
  read -r -p "> " choice
  case "$choice" in
    1) [[ -x "$USER_MANAGER" ]] && "$USER_MANAGER" || { echo "PP5PK user manager is missing."; pause; };;
    2) protocols;; 3) ports_menu;; 4) ambe_menu;; 5) dashboard_menu;;
    6) callhome_menu;; 7) rebuild;; 8) maintenance_menu;; 9) status_menu;;
    10) access_control_menu;; 11) backup_restore_menu;; [Xx]) exit 0;;
  esac
done
