#/bin/bash

# This function when called should create a rendomised list of the playlist according to CHANNEL.
#+ Every file must appear on the list once only.

# Save the list in a file called QUEUE

# Return true unless something went wrong, in which case, write to ERR3.stat and return false.

WPATH="/home/sbadmin"
playerLOG="$WPATH/player.log"
channel="$(cat $WPATH/CHANNEL)"

timestamp()
{
  printf $(date +%d-%m-%y[%H:%M:%S])
}


cat $WPATH/channels/"$channel" | sort -R --random-source=/dev/urandom >$WPATH/QUEUE
printf "\n" >>$WPATH/QUEUE


if [ -s "$WPATH"/QUEUE ]
then
  printf "\n$(timestamp) QUEUE Renewed - Channel: $channel" >>$playerLOG
  exit 0
else
  printf "QUEUE is empty?? Something's not right here - $channel" >"$WPATH"/ERR3.stat
  exit 1
fi


exit 1

