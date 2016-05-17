#/bin/bash

if [ ! "$BASH_VERSION" ]
then
    exec /bin/bash "$0" "$@"
fi

# Based on args provided, this program should schedule a time to add a specific jingle into the QUEUE.
# Arg structure:
	#+ ARG1 "DAYNUM STARTMIN STARTHOUR JINGLE" eg: Sunday from 08:00 Jingle-1  = "0 00 08 jingle1"
	#+ Can be up to 7 ARGS, one for each day, or only one day.

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
WPATH="/home/sbadmin"

argsPrinted=$(echo $@ | tr "'" " ")
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
  printf "\n$(timestamp) Jingles Executed Without Argument! " >> /home/sbadmin/sb.log
  report "Jingles Error" "Jingles.sh was executed with no arguments... ARG: $argsPrinted"
  exit 1
fi

  # Make the schedule.

for arg in "$@"
do
  daynum="$(echo $arg | awk '{print $1}')" # The day, as a number 0-6
  if [ "$daynum" = 0 ]
  then
	dayname="Sunday"
  elif [ "$daynum" = 1 ]
  then
        dayname="Monday"
  elif [ "$daynum" = 2 ]
  then
        dayname="Tuesday"
  elif [ "$daynum" = 3 ]
  then
        dayname="Wednesday"
  elif [ "$daynum" = 4 ]
  then
        dayname="Thursday"
  elif [ "$daynum" = 5 ]
  then
        dayname="Friday"
  elif [ "$daynum" = 6 ]
  then
        dayname="Saturday"
  fi

  startMin="$(echo $arg | awk '{print $2}')" # Start Minute eg: 00
  startHour="$(echo $arg | awk '{print $3}')" # Start Hour eg: 08
  jingle="$(echo $arg | awk '{print $4}')" # Channel eg: All-Music


  printf "$startMin $startHour   * * $daynum     root   (/home/sbadmin/jinglePlay.sh $jingle) \n" > jingleSB$dayname"$startHour""$startMin"

  # Now add a block for the day to show in the UI
 # Pick a color
HEXVAL="$(/usr/bin/xxd -pu <<< $jingle)"
HASH="${HEXVAL:1:6}"

# Strip the file ext.
jingleName="${jingle%.*}"


cat >/var/www/html/elements/jingle$dayname"$startHour""$startMin".txt << _BLOCK_
<div style="background-color: #$HASH" class="scheduleBlock">
<div style="width: 100%; text-align: right;"><div class="scheduleBlockDEL" onclick="window.location.href = '/elements/jingleDelete.php?block=$dayname$startHour$startMin';">&#10007;</div></div>
$jingleName<br />
@ $startHour:$startMin
</div>


_BLOCK_

done

#install new cron file
if sudo mv jingleSB* /etc/cron.d
then
  printf "\n$(timestamp) Jingles Executed: $argsPrinted " >> /home/sbadmin/sb.log
else
  printf "\n$(timestamp) Jingles Executed but failed... ARG: $argsPrinted  " >> /home/sbadmin/sb.log
  report "Jingles.sh Failed" "Was executed, but something went wrong.. ARG = $argsPrinted"
fi

set +x
exit 0



