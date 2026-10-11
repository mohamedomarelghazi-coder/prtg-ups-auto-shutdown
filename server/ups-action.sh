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

Note: the shutdown is scheduled even if docker stop fails (commands are on separate lines, not chained with &&), because a power emergency must never be blocked 
by a container error.
