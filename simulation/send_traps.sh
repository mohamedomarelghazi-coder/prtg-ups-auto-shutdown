#!/bin/bash
# Simulates UPS SNMP v2c traps sent from the Linux VM to PRTG (192.168.56.1).
# Usage: ./send_traps.sh {onbattery|lowbattery|restored}
PRTG=192.168.56.1
COMMUNITY=public_next
OID_TRAP=1.3.6.1.2.1.33.2
OID_VAR=1.3.6.1.2.1.33.1.2.1.0

case "$1" in
  onbattery)  MSG="ALERT :On Battery - Mains Power lost" ;;  # sensor -> yellow
  lowbattery) MSG="Low Battery - ERROR" ;;                   # sensor -> red
  restored)   MSG="Normal - Mains restored" ;;               # sensor -> green
  *) echo "Usage: $0 {onbattery|lowbattery|restored}"; exit 1 ;;
esac

snmptrap -v2c -c "$COMMUNITY" "$PRTG" "" "$OID_TRAP" "$OID_VAR" s "$MSG"
