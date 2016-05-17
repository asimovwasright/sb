#/bin/bash

WPATH="/home/sbadmin"
playerLOG="$WPATH/player.log"
channel="$(cat $WPATH/CHANNEL)"

timestamp()
{
printf $(date +%d-%m-%y[%H:%M:%S])
}

printf "\n$(timestamp) Manual SKIP button pressed" >>$playerLOG

sudo kill -9 "$(pgrep 'omxplayer.bin')"

exit 0
