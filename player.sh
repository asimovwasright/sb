#/bin/bash

# This is the main player which is responsible for the following:
#+ - Playing each file in given channel's queue once.
#+ - During the play-time, write the db for track info, including album art.

# It should be capable of the following:
#+ - Continuing to play the generated list from the point it left off if there is a reboot, or similar event.
#+ - Reporting any issues encountered, especially corrupt files.

# Because the player should basically be running all the time, it should be an infinite loop (after intitial execution that is)
#+ so it's important that it can decide for itslef whether to play or not, based on PLAYSTATE


(
  # Wait for lock on /var/lock/.player.exclusivelock (fd 200) for 10 seconds
  flock -x -w 10 200 || exit 1

########################## CONSTANTS ########################################

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
WPATH="/home/sbadmin"
playerLOG="$WPATH/player.log"

######################## END CONSTANTS ######################################

########################### FUNCTIONS #######################################

timestamp()
{
  printf $(date +%d-%m-%y[%H:%M:%S])
}

report()
{
  # Send email report to admin, and accept parameters for subject and content.
  printf "\n--------Report Entry $(timestamp)-----------\n\nSubject: $1 \nContent: $2 \nUsername: $username\n\n---------------------- END -----------------------\n">>/home/sbadmin/REPORT
}

playstate()
{
  current="$(cat $WPATH/PLAYSTATE)"
  if [ "$current" = 'TRUE' ] || [ "$current" = "PAUSED" ]
  then
    return 0
  else
    return 1
  fi
}

writeTrackInfo()
{
  # For every track which gets played, this function should be run with the track name as ARG1, and playlist as CHANNEL.
  #+ Function should then grab all meta info and compile it into readable format in a file that can
  #+ be grabbed by the UI. This includes the album art.

  avconv -i "$WPATH/LIBRARY/$1" -an -vcodec copy /var/www/html/graphics/images/coverTMP.jpg

  if [ -s /var/www/html/graphics/images/coverTMP.jpg ]
  then
    mv /var/www/html/graphics/images/coverTMP.jpg /var/www/html/graphics/images/cover.jpg
  else
    cp /var/www/html/graphics/images/cover-no-art.jpg /var/www/html/graphics/images/cover.jpg
  fi


  avconv -i "$WPATH/LIBRARY/$1" -f ffmetadata "$WPATH/metadata.tmp"

  artist="$(awk -F '=' '/^artist=/ {print $2}' $WPATH/metadata.tmp)"
  album="$(awk -F '=' '/^album=/ {print $2}' $WPATH/metadata.tmp)"
  title="$(awk -F '=' '/^title=/ {print $2}' $WPATH/metadata.tmp)"

  # Add the track to played log.

  printf "$(timestamp)-:-$artist-:-$album-:-$title\n" >>$WPATH/play-history.log


  # Write out the now-playing box.

# Start with the album art
cat >$WPATH/now-playing.php-TMP << _NOWPLAYING_
<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" type="text/css" href="../graphics/css/elements.css" />
</head>
<body>

<div id="albumArt"><img src="../graphics/images/cover.jpg" />
	<div id="nowPlaying">
	<table>
	<tr>
	<td> <strong style="color: white;">$title</strong></td>
	</tr>
	<tr>
	<td>  <strong style="color: #DEE0E0">$artist</strong></td>
	</tr>
	</table>
	</div>
</div><!-- End albumArt -->
_NOWPLAYING_

  rm "$WPATH/metadata.tmp"

  # Open the HTML tmp file to begin writing the play-list.php for UI

cat >>$WPATH/now-playing.php-TMP <<_PLAYLIST_

<div id="playList">
<table>
<tr>
<td colspan="2"><hr></hr></td>
</tr>
_PLAYLIST_

  # Now begin a loop through the next 5 tracks in the current queue, and pull info for playlist in UI.

  count=6
  until [ "$count" = 0 ]
  do
    file="$(head -$count $WPATH/QUEUE | tail -1)"
    ffmpeg -i "$WPATH/LIBRARY/$file" -f ffmetadata "$WPATH/metadata.tmp"
    # Grab data and place into HTML in tmp file
    artist="$(awk -F '=' '/^artist=/ {print $2}' $WPATH/metadata.tmp)"
    title="$(awk -F '=' '/^title=/ {print $2}' $WPATH/metadata.tmp)"
    # Set the row color based on the count value.
    if [ "$count" = 6 ]
    then
      color="color: #31453E;"
    elif [ "$count" = 5 ]
    then
      color="color: #3E6356;"
    elif [ "$count" = 4 ]
    then
      color="color: #45806C;"
    elif [ "$count" = 3 ]
    then
      color="color: #7BAD9C;"
    elif [ "$count" = 2 ]
    then
      color="color: #B2D4C8;"
    else
      color="color: white;"
    fi
    # Now place in the markup and add to tmp file.
    if [ "$count" = 1 ]
    then

cat >>$WPATH/now-playing.php-TMP <<_ADDLINE_
<tr>
<td colspan="2"><hr></hr></td>
</tr>
<tr id="currentTrack" style="color:#ffffff;">
<td><br/>$title<br/><br/></td><td><br/>$artist<br/><br/></td>
</tr>
<tr>
<td colspan="2"><hr></hr></td>
</tr>
_ADDLINE_

    else

cat >>$WPATH/now-playing.php-TMP <<_ADDLINE_
<tr style="$color">
<td>$title</td><td>$artist</td>
</tr>
_ADDLINE_

    fi
    rm $WPATH/metadata.tmp
    count="$((count -1))"
  done

  # Now add the passed 5 tracks to play-list.php

  count=2
  until [ "$count" = 7 ]
  do
    file="$(tail -$count $WPATH/play-history.log | head -1)"
    artist="$(echo $file | awk -F '-:-' '{print $2}')"
    album="$(echo $file | awk -F '-:-' '{print $3}')"
    title="$(echo $file | awk -F '-:-' '{print $4}')"

    # Set the colours for the rows
    if [ "$count" = 5 ]
    then
      color="color: #3B3B3B;"
    elif [ "$count" = 4 ]
    then
      color="color: #595959;"
    elif [ "$count" = 3 ]
    then
      color="color: #858585;"
    elif [ "$count" = 2 ]
    then
      color="color: #B8B8B8;"
    elif [ "$count" = 1 ]
    then
      color="color: #DBDBDB;"
    fi

cat >>$WPATH/now-playing.php-TMP <<_ADDLINE_
<tr style="$color">
<td>$title</td><td>$artist</td>
</tr>
_ADDLINE_

    count="$((count +1))"
  done

  # Now end the HTML tmp file

cat >>$WPATH/now-playing.php-TMP <<_PLAYLIST_
<tr>
<td colspan="2"><hr></hr></td>
</tr>

</table>
</div>
<div id="skipButton"><iframe class="actionButton" scrolling="no" src="/elements/skip-button.php">Button Not Loaded</iframe></div>

<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.0/jquery.min.js"></script>
<script src="../js/crc32.js"></script>
</script>
</body>

</html>

_PLAYLIST_


  # Now move the tmp file to replace the actual one.

  mv $WPATH/now-playing.php-TMP /var/www/html/elements/now-playing.php

  return 0
}

playSong()
{
  # On call, if file exsists in LIBRARY, play the file in ARG1 from playlist in CHANNEL
  if find "$WPATH/LIBRARY" -name "$1"
  then
#    sudo mv /root/omxplayer.log $WPATH/trackLOGS/$(timestamp).txt # Grab the previous log and move to directory.
    PLAYER="mpg123" # -g for logging
    writeTrackInfo "$1" &
    $PLAYER "$WPATH/LIBRARY/$1"
    return true
  else
    return false
  fi
}


######################### END FUNCTIONS ####################################



####################### MAIN LOOP ##########################################

printf "\n\n\n----------- $(timestamp) Player START ------------\n\n\n" >>$playerLOG

# First initialise the infinite loop

while :
do
  QUEUE="$WPATH/QUEUE"
  # Check if there is currently a QUEUE to be played.
  if ! [ -s "$QUEUE" ] # There is no queue, or it is empty.
  then
    # Call to generate random list
    if ! $WPATH/generateQueue.sh # If the playlist generator returns false?
    then
      printf "\n$(timestamp) Could not generate playlist!" >>$playerLOG
      printf "\n$(timestamp) Could not generate playlist, stopping Player now!" >> /home/sbadmin/sb.log
      printf "\n\n\n----------- $(timestamp) Player STOP ------------\n\n\n" >>$playerLOG
      reporter "Playlist Failed!" "Could not generate playlist for player to use.\n User: $username"
      sudo rm /var/lock/.player.exclusivelock # Remove the lock on the script, so it can play again.
    exit 1
    fi
  fi

  # Now start playing the list one by one.
  # Logic: Always play the first line in QUEUE
  #+ Then remove that line from QUEUE, add to HISTORY
  # Once QUEUE is empty, run generateQueue.sh
  while [ $(cat "$QUEUE" | wc -l) -gt 0 ]
  do
    if ! playstate # Only returns true if the playstate is TRUE
    then # If not?
      printf "\n\n\n----------- $(timestamp) Player STOP ------------\n\n\n" >>$playerLOG
      sudo rm /var/lock/.player.exclusivelock # Remove the lock on the script, so it can play again.
      exit 0
    fi
    printf "\n$(timestamp) Playing  $(head -1 $QUEUE)" >>$playerLOG
    channel="$(cat $WPATH/CHANNEL)"
    playSong "$(head -1 $QUEUE)"
    tail -n +2 "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
  done
done



##################### END MAIN LOOP ########################################


) 200>/var/lock/.player.exclusivelock






