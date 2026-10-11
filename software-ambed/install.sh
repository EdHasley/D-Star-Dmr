#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo bash software-ambed/install.sh'; exit 1; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
port=${1:-10100}
peer=${2:-}
[[ $port =~ ^[0-9]+$ ]] && ((port >= 1024 && port <= 65509)) || { echo 'Port must be 1024–65509'; exit 1; }
[[ -n $peer ]] || peer=$(awk '/^ExecStart=\/xlxd\/xlxd / {print $3; exit}' /etc/systemd/system/xlxd.service)
python3 - "$peer" <<'PY'
import ipaddress, sys
assert ipaddress.ip_address(sys.argv[1]).version == 4
assert sys.argv[1] not in ('0.0.0.0', '127.0.0.1'), 'XLXD must bind a different address from the local software service'
PY
if systemctl is-active --quiet ambed.service; then
    echo 'Hardware AMBED is running. Stop it before selecting the software backend.'; exit 1
fi
make -C "$root" -j2
install -m 0755 "$root/software-ambed" /usr/local/bin/software-ambed
cat > /etc/systemd/system/software-ambed.service <<EOF
[Unit]
Description=AF0WX experimental software D-Star DMR transcoder
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
DynamicUser=yes
ExecStart=/usr/local/bin/software-ambed --listen 127.0.0.1 --peer $peer --port $port --channels 4
Restart=on-failure
RestartSec=3
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
RestrictAddressFamilies=AF_INET AF_UNIX

[Install]
WantedBy=multi-user.target
EOF
if [[ -f /etc/extended-name-reflector/reflector.conf ]]; then
    sed -i -E '/^TRANSCODER_BACKEND=/d; /^TRANSCODER_ENABLED=/d; /^TRANSCODER_PORT=/d' /etc/extended-name-reflector/reflector.conf
    printf 'TRANSCODER_BACKEND="software"\nTRANSCODER_ENABLED="N"\nTRANSCODER_PORT="%s"\n' "$port" >> /etc/extended-name-reflector/reflector.conf
fi
systemctl daemon-reload
if [[ ${3:-} != --no-start ]]; then
    systemctl enable --now software-ambed.service
fi
echo "Software transcoder installed on loopback UDP $port; XLXD peer $peer."
