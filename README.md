# PRTG UPS Auto-Shutdown Lab

Reactive monitoring lab: a simulated UPS sends SNMP Traps to **PRTG**, which reacts automatically by alerting users and, on low battery, cleanly stopping Docker containers and shutting down a Linux server.

> **Note:** there is no physical UPS. The UPS is simulated by a Linux VM that sends SNMP v2c Traps to PRTG.



---

## Architecture

```
 ┌──────────────────┐   SNMP Trap (UDP 162)   ┌────────────────────┐
 │  Linux VM        │ ──────────────────────► │  PRTG server       │
 │  (simulated UPS) │                         │  (Windows)         │
 │  snmptrap        │ ◄────────────────────── │  SNMP Trap Receiver│
 └──────────────────┘   SNMP polling (161)    └─────────┬──────────┘
                                                        │ state change
                                                        │ (yellow / red / green)
                                                        ▼
                                            Notification: e-mail (Gmail SMTP)
                                            + .bat script -> ssh.exe
                                                        │ SSH (key only,
                                                        │ forced command)
                                                        ▼
                                        ┌────────────────────────────────┐
                                        │ Target server (Ubuntu)         │
                                        │ 192.168.56.10                  │
                                        │ Docker: app_rh, db_finance,    │
                                        │         cache_it               │
                                        │ ufw firewall                   │
                                        └────────────────────────────────┘
```

| Component | Role |
|---|---|
| PRTG (Windows) | Collects SNMP data, receives Traps (UDP 162), triggers notifications |
| Target server (Ubuntu, 192.168.56.10) | Production machine running Docker apps, protected by ufw |
| Linux VM | Simulates the UPS by sending Traps with `snmptrap` |

### Docker containers

| Name | Image | Role |
|---|---|---|
| `app_rh` | nginx:alpine | HR web app (port 8081) |
| `db_finance` | postgres:15-alpine | Finance database |
| `cache_it` | redis:alpine | Cache |

---

## The three scenarios

| **Mains lost** (on battery) | `ALERT :On Battery - Mains Power lost` | 🟡 Warning | E-mail + `01_mains_lost.bat` | `wall` message to logged-in users |
| **Low battery** | `Low Battery - ERROR` | 🔴 Error | E-mail + `02_low_battery_shutdown.bat` | Containers stopped, `shutdown -h +2`, `wall` message |
| **Mains restored** | `Normal - Mains restored` | 🟢 OK | `03_mains_restored.bat` | `shutdown -c` cancels shutdown, `wall` info message |

### Event chain (low battery)

1. The Linux VM sends an SNMP Trap to PRTG (UDP 162).
2. PRTG's SNMP Trap Receiver sensor captures it and evaluates it against its filters. i configured certain bindings to filter the traps messages like "On Battery" "Mains Restored" .
3. The sensor changes state, which fires the matching notification trigger.
4. PRTG sends an e-mail and runs a `.bat` file that calls `ssh.exe`.
5. On the server, a forced-command script stops the containers, broadcasts a message, and runs `shutdown -h +2`.



## Security design

The goal is that **PRTG can trigger three actions and nothing else**.

1. **Dedicated user `prtgups`**, with no password (key authentication only).
2. **Forced command in `authorized_keys`**: whatever the client sends, SSH runs `/usr/local/bin/ups-action.sh`. The client's request is only read as an action name (`mains_lost`, `low_battery`, `mains_restored`); anything else returns `Denied`.
3. **`restrict` option**: disables port forwarding, agent forwarding, TTY and X11.
4. **Sudo limited to exact commands**: only `docker stop` on the three containers, `shutdown -h +2`, `shutdown -c`, and `wall`.
5. **Negative test**: asking for `cat /etc/shadow` returns `Denied`.

### `server/ups-action.sh` (installed in `/usr/local/bin/`, owner root, mode 755)

```bash
#!/bin/bash
# Forced-command wrapper: PRTG can only trigger these 3 actions.
case "$SSH_ORIGINAL_COMMAND" in
  mains_lost)
    echo 'ALERT: Alimentation secteur perdue ! Passage sur onduleur. Sauvegardez vos travaux.' | sudo /usr/bin/wall
    ;;
  low_battery)
    sudo /usr/bin/docker stop app_rh db_finance cache_it
    sudo /usr/sbin/shutdown -h +2 'ALERTE BATTERIE FAIBLE : Arret automatique des conteneurs. Extinction du systeme dans 2 minutes.'
    ;;
  mains_restored)
    sudo /usr/sbin/shutdown -c
    echo 'INFORMATION : Le courant secteur est retabli. Vous pouvez continuer vos travaux.' | sudo /usr/bin/wall
    ;;
  *)
    echo "Denied"; exit 1
    ;;
esac
```

Note: the shutdown is scheduled even if `docker stop` fails (commands are on separate lines, not chained with `&&`), because a power emergency must never be blocked by a container error.

### `server/sudoers_prtgups.example` (installed with `sudo visudo -f /etc/sudoers.d/prtgups`)

```
prtgups ALL=(root) NOPASSWD: /usr/bin/docker stop app_rh db_finance cache_it, /usr/sbin/shutdown -h +2 *, /usr/sbin/shutdown -c, /usr/bin/wall ""
```

### `server/authorized_keys.example` (`/home/prtgups/.ssh/authorized_keys`, mode 600)

```
command="/usr/local/bin/ups-action.sh",restrict ssh-rsa AAAA...FAKE-KEY-REPLACE-ME... prtg
```

### PRTG scripts (example: `02_low_battery_shutdown.bat`)

```bat
@echo off
REM Triggered by PRTG when the sensor turns RED (Low battery).
"C:\Windows\System32\OpenSSH\ssh.exe" -i "C:\PRTGKey\ssh.txt" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o BatchMode=yes prtgups@192.168.56.10 low_battery >> C:\PRTGKey\prtg_debug.log 2>&1
```

The other two are identical with `mains_lost` and `mains_restored` as the action.

---

## Setup

### 1. Target server (Ubuntu)
(copy ups-action.sh to the server first)
#1. Create the dedicated user (key authentication only)
sudo adduser --disabled-password --gecos "" prtgups

# 2. Install the forced-command wrapper (root-owned, not writable by prtgups)
sudo cp server/ups-action.sh /usr/local/bin/ups-action.sh
sudo chown root:root /usr/local/bin/ups-action.sh
sudo chmod 755 /usr/local/bin/ups-action.sh

# 3. Restrict sudo to the exact commands needed
sudo visudo -f /etc/sudoers.d/prtgups     # paste the line from server/sudoers_prtgups.example
sudo visudo -c                             # must say: parsed OK
sudo -l -U prtgups                         # must list only the 4 allowed commands

# 4. Install the restricted public key
sudo mkdir -p /home/prtgups/.ssh
echo 'command="/usr/local/bin/ups-action.sh",restrict ssh-rsa AAAA...YOUR-PUBLIC-KEY... prtg' | sudo tee /home/prtgups/.ssh/authorized_keys
sudo chown -R prtgups:prtgups /home/prtgups/.ssh
sudo chmod 700 /home/prtgups/.ssh
sudo chmod 600 /home/prtgups/.ssh/authorized_keys
(Generate the keypair on the PRTG server with ssh-keygen -t ed25519)

### 2. PRTG server (Windows)

- Place the private key in `C:\PRTGKey\`.
- Open **UDP 162** in the Windows firewall for the Trap receiver.
- Create the SNMP Trap Receiver sensor and its filters. <img width="281" height="290" alt="image" src="https://github.com/user-attachments/assets/96611aa3-c877-4078-9145-2ca768239411" />, 

- Create three notification templates, i honestly used claude for templates for the 3 states i implemented.
- Create state triggers: Warning -> mail + script 01, Down -> mail + script 02, Up -> script 03. 
<img width="757" height="791" alt="image" src="https://github.com/user-attachments/assets/0428b700-16db-475c-a720-d6a785ec2ac0" />

### 3. Simulation (Linux VM)

The UPS is simulated by sending SNMP v2c Traps from the Linux VM to PRTG (192.168.56.1):

# Mains lost -> sensor turns yellow
snmptrap -v2c -c public_next 192.168.56.1 '' 1.3.6.1.2.1.33.2 1.3.6.1.2.1.33.1.2.1.0 s "ALERT :On Battery - Mains Power lost"

# Low battery -> sensor turns red
snmptrap -v2c -c public_next 192.168.56.1 '' 1.3.6.1.2.1.33.2 1.3.6.1.2.1.33.1.2.1.0 s "Low Battery - ERROR"

# Mains restored -> sensor turns green
snmptrap -v2c -c public_next 192.168.56.1 '' 1.3.6.1.2.1.33.2 1.3.6.1.2.1.33.1.2.1.0 s "Normal - Mains restored"


## Firewall (ufw)

See `docs/ufw_status.txt`. Default policy: deny incoming, allow outgoing. Open: 22/tcp (SSH), 161/udp (SNMP polling), 514/udp (syslog).

---

## Known limitations and next steps

- **Lab simplifications:** `StrictHostKeyChecking=no` and `UserKnownHostsFile=NUL` skip server identity checks. In production, pin the host key.
- The SSH keypair was generated on the Linux VM. Better practice: generate it on the PRTG server (`ssh-keygen -t ed25519`) so the private key exists in one place only.
- `mains_restored` cancels the shutdown but does **not** restart the stopped containers. Next step: add `docker start` for the three containers (and the matching sudoers entry).
- The community string `public_next` is a lab value.
- Next steps: Teams notifications, compare with **NUT / apcupsd** (the standard tools for real UPS shutdown) and eventually test with a real UPS.

## Skills practised

SNMP (Traps, OIDs, polling) · PRTG sensors, notifications and triggers · Linux administration · SSH key authentication and forced commands · sudo least privilege · Docker · ufw · Windows batch and Bash scripting

## Author

Omar El Ghazi, networks and telecommunications engineering student · [https://www.linkedin.com/in/mohamed-omar-el-ghazi-362b3521b/?isSelfProfile=true]
