# PRTG settings

> Fill in the [TO COMPLETE] parts from your PRTG web interface. Never show passwords.

## 1. SNMP Trap Receiver sensor
- Listening port: UDP 162 (allowed in the Windows firewall)
- Community string: public_next (lab value)
- Filter rules (on the message text):
  - contains "On Battery"  -> [TO COMPLETE: warning]
  - contains "Low Battery" -> [TO COMPLETE: error]
  - contains "Normal"      -> [TO COMPLETE: OK]
- Channel limits producing yellow / red: [TO COMPLETE]

Screenshot: images/sensor_settings.png

## 2. Notification templates
| Name | Type | What it does |
|---|---|---|
| Mail alert | Send email (Gmail SMTP, app password) | Warning e-mail |
| Mail emergency | Send email (Gmail SMTP, app password) | Emergency e-mail |
| Script mains lost | Execute program | 01_mains_lost.bat |
| Script low battery | Execute program | 02_low_battery_shutdown.bat |
| Script mains restored | Execute program | 03_mains_restored.bat |

SMTP server: smtp.gmail.com (port [TO COMPLETE]), app password (not shown).

## 3. State triggers (on the sensor)
| State | Notifications |
|---|---|
| Warning | Mail alert + Script mains lost |
| Down | Mail emergency + Script low battery |
| Up | Script mains restored |

[TO COMPLETE: confirm against your configuration]

Screenshot: images/notifications.png
