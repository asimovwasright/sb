#!/bin/bash

# When executed by scheduleDelete.php, this program should:
#+	Remove the schedule from cron.d
#+	Remove the txt file for UI

rm /etc/cron.d/scheduleSB$1
rm /var/www/html/elements/schedule$1.txt

exit
