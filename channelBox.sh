#/bin/bash

# This program should be able to create the channel-box.php page.
# The page needs to have a button for each available playlist, with its respective name.
# The active channel should have the id='active' atribute.
# Each inactive button should have an onclick atribute which executes
#+ this program with the argument of which channel to change to.

# After creating the channel-box.php, it should rewrite CHANNEL and execute generateQueue.sh
#+ but ONLY if CHANNEL has changed...

# Error reporting through report() function, and ERR4.stat

if [ ! "$BASH_VERSION" ]
then
    exec /bin/bash "$0" "$@"
fi


############# CONSTANTS ###################

WPATH="/home/sbadmin"
username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
conf="/home/sbadmin/sb.conf"

###########################################


############ FUNCTIONS ####################

timestamp()
{
  printf $(date +%d-%m-%y[%H:%M:%S])
}

report()
{
  # Send email report to admin, and accept parameters for subject and content.
  printf "\n--------Report Entry $(timestamp)-----------\n\nSubject: $1 \nContent: $2 \nUsername: $username\n\n---------------------- END -----------------------\n">>/home/sbadmin/REPORT
}

###########################################

# First check if the ARG1 exists, and if it is a possible playlist.

if [ $# -eq 0 ]
then
  report "channelBox executed with no argument" "The channelBox program was executed with no Channel in the argument."
  printf "\nFailed to create Channel Selection... $(timestamp)" > /home/sbadmin/ERR4.stat
  printf "\n$(timestamp) Failed to create Channel Box, no Channel provided." >> /home/sbadmin/sb.log
  exit 1
elif [ ! -s "$WPATH/channels/$1" ]
then
  report "channelBox executed with bad argument" "The channelBox program was executed with a channel that doesn't exist or is empty: $1."
  printf "\nFailed to create Channel Selection... $(timestamp)" > /home/sbadmin/ERR4.stat
  printf "\n$(timestamp) Failed to create Channel Box, bad Channel provided: $1." >> /home/sbadmin/sb.log
  exit 2
fi

# Now that we know we can move forward, change the channel and queue files, and start making the page:
channel="$(cat $WPATH/CHANNEL)"
if [ "$channel" != "$1" ] # Channel has changed - need to backup the current queue, and restore the new queue if it exists.
then
  printf "$1" >"$WPATH/CHANNEL"
  cp $WPATH/QUEUE $WPATH/$channel.QB
  if [ -s  $WPATH/$1.QB ] # There was a queue already in use for this channel. Use it up to avoid repitition.
  then
      printf "\n$(timestamp) $WPATH/$1.QB copying to $WPATH/QUEUE" >> /home/sbadmin/player.log
      mv $WPATH/$1.QB $WPATH/QUEUE
      printf "\n$(timestamp) Channel $1 Resuming Queue" >> /home/sbadmin/player.log
  else # Must be the first time this channel has been chosen, since there is no queue file.
    printf "\n$(timestamp) Channel $1 Used for the first time." >> /home/sbadmin/player.log
      $WPATH/generateQueue.sh
  fi
  # Re-evaluate the channel
  channel="$(cat $WPATH/CHANNEL)"
fi

printf "\n$(timestamp) Channels Updated!" >> /home/sbadmin/player.log

# Opening Tags etc...
cat >/var/www/html/elements/channel-box.php << _CHANNELS_
<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" type="text/css" href="../graphics/css/elements.css" />
<script type="text/JavaScript">
function changeChannel(a)
{
  var buttons = document.getElementsByTagName("td");
  for(var i = 0; i < buttons.length; i++){
    buttons[i].className += " noclick";
    buttons[i].onclick = function() {
     return false;
   }
  }
  var pressed = document.getElementById(a);
  pressed.className += " pressed";
  var url = "./change-channel.php?channel=" + encodeURIComponent(a);
  http = new XMLHttpRequest();
  http.open("GET", url, true);
  http.send(null);
}
</script>
</head>
<body id="channel-dial" >
	<p><i>Channel schedule will resume at the next scheduled change.</i></p><br />

_CHANNELS_


# Now loop through the playlists in channels directory and create the respective buttons.
list="$(ls -1 $WPATH/channels)" # Grabs the list of playlists.

for playlist in $list
do
  # Pick a color

HEXVAL=$(xxd -pu <<< "$playlist")
HASH="${HEXVAL:1:6}"

  # Add it to the new channelSelect.txt for the scheduler.

cat >>/var/www/html/elements/channelSelect.TMP <<_CHANNELSELECT_
  <option style="color: #$HASH" value="$playlist">$playlist</option>
_CHANNELSELECT_

  if [ "$playlist" = "$channel" ] # This is the active channel's button, no need for onclick atribute, and must have active ID atribute.
  then
	# Add table to PHP
cat >>/var/www/html/elements/channel-box.php << _BUTTON_
<table>
 <tr>
  <td style="background-color:#$HASH" id="active">
    $playlist
  </td>
 </tr>
</table>
_BUTTON_
  else # This is not the active channel, and must have correct onlick atribute.
	# Add table to PHP

cat >>/var/www/html/elements/channel-box.php << _BUTTON_
<table>
 <tr>
  <td id="$playlist" style="background-color:#$HASH" onclick="changeChannel('$playlist');">
    $playlist
  </td>
 </tr>
</table>
_BUTTON_
  fi
done

# Add the 'STOP' option for channelSelect
cat >>/var/www/html/elements/channelSelect.TMP <<_CHANNELSELECT_
  <option style="color: red" value="STOP">STOP</option>
_CHANNELSELECT_

# Overwrite the old channelSelect with new one.
mv /var/www/html/elements/channelSelect.TMP /var/www/html/elements/channelSelect.txt

# Now end the HTML tags
cat >>/var/www/html/elements/channel-box.php << _CHANNELS_
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.0/jquery.min.js"></script>
<script src="../js/crc32.js"></script>
</body>
</html>
_CHANNELS_

exit 0
