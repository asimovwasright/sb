#!/bin/bash

# This is the program called by the php counterpart - and needs to either pause OMXPlayer - or resume based on the single
#+ arg: "play" or "pause"

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
ftpmasterlog="/home/sbadmin/ftpLOG"
conf="/home/sbadmin/sb.conf"
WPATH="/home/sbadmin"
ip="$(ip addr show eth0 | grep inet | grep global | awk '{print $2}')"

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

if [ "$1" = "pause" ]
then
  sudo rm $WPATH/PLAYSTATE
  printf "PAUSED" >$WPATH/PLAYSTATE
elif [ "$1" = "play" ]
then
  sudo rm $WPATH/PLAYSTATE
  printf "TRUE" >$WPATH/PLAYSTATE
fi

if [ "$1" = "pause" ]
then
  for i in {100..50}
  do
    sudo amixer set PCM -- $i%
  done
  sudo amixer set PCM -- 0%
elif [ "$1" = "play" ]
then
  for i in {50..100}
  do
    sudo amixer set PCM -- $i%
  done
fi


exit 0
