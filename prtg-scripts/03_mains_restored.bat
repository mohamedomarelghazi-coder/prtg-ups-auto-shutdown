@echo off
"C:\Windows\System32\OpenSSH\ssh.exe" -i "C:\PRTGKey\ssh.txt" -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL -o BatchMode=yes adminnet@192.168.56.10 "sudo shutdown -c && echo 'INFORMATION : Le courant secteur est retabli. Le systeme fonctionne normalement, vous pouvez continuer vos travaux.' | sudo wall" >> C:\PRTGKey\prtg_debug.log 2>&1
