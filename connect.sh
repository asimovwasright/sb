#/bin/bash

# This will be the very first script to run on reboot. The point will be to try to connect to internet.
#+ Either by DHCP (ideally) or by trying to find a connect.conf file, which will need to be preloaded.

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
ftpmasterlog="/home/sbadmin/ftpLOG"
conf="/home/sbadmin/sb.conf"
WPATH="/home/sbadmin"

############################### FUNCTIONS ########################################################

timestamp()
{
  printf $(date +%d-%m-%y[%H:%M:%S])
}

report()
{
  # Send email report to admin, and accept parameters for subject and content.
  printf "\n--------Report Entry $(timestamp)-----------\n\nSubject: $1 \nContent: $2 \nUsername: $username\n\n---------------------- END -----------------------\n">>/home/sbadmin/REPORT
}


# For now, just wait a few minutes after boot, then execute primary.sh

sleep 30

if ping -c5 8.8.8.8 || ping -c5 83.81.90.114
then
  # Clearly working
  touch "$WPATH"/Connect-Working
else
  report "Connect Failed" "Tried to connect, but cannot create connection."
fi


# Start the player going before doing anything else, everything else can be done in the background.

(bash -c '/home/sbadmin/player.sh &')

sleep 10
if pgrep "omxplayer.bin"
then
 printf "\n$(timestamp) Started Player" >>/home/sbadmin/sb.log
else
 printf "\n$(timestamp) Failed to start Player" >>/home/sbadmin/sb.log
 report "Couldn't start Player" "Tried to start the player after Connect.sh ran, but it did not work..."
fi

# Run Primary, since the device has just booted, and we don't know how long it has been down for.

bash -c '/home/sbadmin/primary.sh &'

exit 0
