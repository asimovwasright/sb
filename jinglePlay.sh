#!/bin/bash

# When called by cron.d, this program should take the argumented file, and plae it at the top of the QUEUE.
# This will play the jingle at the required time, but will not interupt the music.

if [ ! "$BASH_VERSION" ]
then
    exec /bin/bash "$0" "$@"
fi

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
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

# Log Everything.

if [ "$#" -lt 1 ]
then
  printf "\n$(timestamp) Jingle Play Executed Without Argument! " >> /home/sbadmin/sb.log
  report "Jingle Queue Error" "Jingle Play was executed with no arguments... ARG: $1"
  exit 1
fi


# So far, so good, let's try to place the file.

jingle="$1"

if sed -i "1 a/JINGLES/$jingle" "$WPATH"/QUEUE
then
  printf "\n$(timestamp) Jingle QEUED: $jingle " >> /home/sbadmin/sb.log
else
  printf "\n$(timestamp) Jingle Failed to QUEUE: $jingle" >> /home/sbadmin/sb.log
  report "Jingle Queue Error" "Could not add to QUEUE - ARG: $jingle"
fi

exit 0
