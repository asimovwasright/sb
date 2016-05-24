#/bin/bash

# This script should be used to hard stop the player (only by admin) and also to activate a scheduled stop, which only stops after the track has completed.

# ARG1 will determine the type of stop.

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

# Change the Track info so the UI shows the player is stopping.

cp /var/www/html/graphics/images/sleeping.jpg /var/www/html/graphics/images/cover.jpg

cat >/var/www/html/elements/now-playing.php << _NOWPLAYING_
<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" type="text/css" href="../graphics/css/elements.css" />
</head>
<body>
<div id="albumArtSleeping"><img src="../graphics/images/cover.jpg" />
	<div id="nowPlaying">
	<table>
	<tr>
	<td>  <strong style="color: #DEE0E0"><i>Check the schedule for next session.</i></strong></td>
	</tr>
	</table>
	</div>
</div><!-- End albumArt -->
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.12.0/jquery.min.js"></script>
<script src="../js/crc32.js"></script>
</script>
</body>
</html>
_NOWPLAYING_

if [ "$1" != "SCHEDULE" ]
then
  echo FALSE>/home/sbadmin/PLAYSTATE
  printf "\n$(timestamp) HARD STOP! Stopping Without Delay" >> /home/sbadmin/player.log
  sudo /home/sbadmin/skip.sh
  exit 0
else
  echo FALSE>/home/sbadmin/PLAYSTATE
  printf "\n$(timestamp) Scheduled Stop - Player stopping after current track." >> /home/sbadmin/player.log
  exit 0
fi

report "Stop Failed" "Stop was called but for some reason did not work correctly. \n ARG was: $1"

exit 1
