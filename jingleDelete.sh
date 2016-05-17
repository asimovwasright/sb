#!/bin/bash

# When executed by jingleDelete.php, this program should:
#+	Remove the jingle schedule from cron.d
#+	Remove the txt file for UI

rm /etc/cron.d/jingleSB$1
rm /var/www/html/elements/jingle$1.txt

exit
