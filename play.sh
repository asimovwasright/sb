#/bin/bash

# This script should simply start the player.

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
WPATH="/home/sbadmin"

timestamp()
{
printf $(date +%d-%m-%y[%H:%M:%S])
}

report()
{
# Send email report to admin, and accept parameters for subject and content.
printf "\n--------Report Entry $(timestamp)-----------\n\nSubject: $1 \nContent: $2 \nUsername: $username\n\n---------------------- END -----------------------\n">>/home/sbadmin/REPORT
}


printf "\n$(timestamp) Scheduled Start - Player starting." >> /home/sbadmin/player.log
printf "TRUE" >/home/sbadmin/PLAYSTATE

sleep 5

sudo su sbadmin '/home/sbadmin/player.sh'


exit 0
