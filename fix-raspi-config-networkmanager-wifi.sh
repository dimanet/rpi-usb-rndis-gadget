#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

TARGET=/usr/bin/raspi-config
BACKUP=/usr/bin/raspi-config.bak-networkmanager-wifi

python3 - <<'PY'
from pathlib import Path
p = Path('/usr/bin/raspi-config')
text = p.read_text()
old = '''  else
    IFACE="$(list_wlan_interfaces | head -n 1)"
    if [ "$HIDDEN" -ne 0 ]; then
      nmcli device wifi connect "$SSID" password "$PASSPHRASE" ifname "${IFACE}" hidden true | grep -q "activated"
    else
      nmcli device wifi connect "$SSID" password "$PASSPHRASE" ifname "${IFACE}" | grep -q "activated"
    fi
    RET=$((RET + $?))
  fi
'''
new = '''  else
    IFACE="$(find /sys/class/net -mindepth 1 -maxdepth 1 -type l | while read -r d; do [ -d "$d/wireless" ] && basename "$d"; done | head -n 1)"
    CON_NAME="$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2 == "802-11-wireless" { print $1; exit }')"
    if [ -z "$CON_NAME" ]; then
      CON_NAME="$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2 == "802-11-wireless" { print $1; exit }')"
    fi
    if [ -z "$CON_NAME" ]; then
      CON_NAME="raspi-config-$SSID"
      nmcli connection add type wifi ifname "${IFACE}" con-name "$CON_NAME" ssid "$SSID" > /dev/null
      RET=$((RET + $?))
    else
      nmcli connection modify "$CON_NAME" 802-11-wireless.ssid "$SSID" > /dev/null
      RET=$((RET + $?))
    fi
    if [ -z "$PASSPHRASE" ]; then
      nmcli connection modify "$CON_NAME" 802-11-wireless-security.key-mgmt none > /dev/null
      RET=$((RET + $?))
    else
      nmcli connection modify "$CON_NAME" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk "$PASSPHRASE" > /dev/null
      RET=$((RET + $?))
    fi
    if [ "$HIDDEN" -ne 0 ]; then
      nmcli connection modify "$CON_NAME" 802-11-wireless.hidden true > /dev/null
      RET=$((RET + $?))
    else
      nmcli connection modify "$CON_NAME" 802-11-wireless.hidden false > /dev/null
      RET=$((RET + $?))
    fi
    if [ $RET -eq 0 ] && ! nmcli -t -f TYPE,DEVICE connection show --active 2>/dev/null | grep -q '^802-11-wireless:wlan'; then
      nmcli connection up "$CON_NAME" ifname "${IFACE}" > /dev/null
      RET=$((RET + $?))
    fi
  fi
'''
if new in text:
    print('already patched')
    raise SystemExit(0)
if old not in text:
    raise SystemExit('target block not found; raspi-config version may have changed')
backup = Path('/usr/bin/raspi-config.bak-networkmanager-wifi')
if not backup.exists():
    backup.write_text(text)
p.write_text(text.replace(old, new, 1))
print('patched')
PY

bash -n "$TARGET"
echo "Patched $TARGET (backup: $BACKUP)"
