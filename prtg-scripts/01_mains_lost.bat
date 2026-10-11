@echo off
"C:\Windows\System32\OpenSSH\ssh.exe" -i "C:\PRTGKey\ssh.txt" -o StrictHostKeyChecking=no adminnet@192.168.56.10 "echo 'ALERT: Alimentation secteur perdue ! Passage sur onduleur. Sauvegardez vos travaux.' | sudo wall"
