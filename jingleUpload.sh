#!/bin/bash

# This function is executed by its PHP counterpart, and when executed is responsible for:
#+ Making of the jinglesSelect.txt file for the UI to display possible jingle files.
#+ Take the recently uploaded jingle track and test it for usability.

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

# Log Everything


if [ "$(ls -1 $WPATH/LIBRARY/JINGLES/ | wc -l)" -lt 1 ]
then
  printf "\n$(timestamp) No Jingles Found! " >> /home/sbadmin/sb.log
  report "Jingles Missing" "JingleUpload was executed and found zero jingles."
  exit 1
fi


# So far, so good

# For each object in the Jingles directory, make an entry in the jinglesSelect.txt


for jingle in "$WPATH"/LIBRARY/JINGLES/*
do
  # Strip the pathname
  jingle="$(basename $jingle)"
  # Strip the file ext.
  jingleName="${jingle%.*}"

  # Pick a color
  HEXVAL=$(xxd -pu <<< "$jingle")
  HASH="${HEXVAL:1:6}"

  # Add it to the new channelSelect.txt for the scheduler.

cat >>/var/www/html/elements/jinglesSelect.TMP <<_SELECT_
  <option style="color: #$HASH" value="$jingle">$jingleName</option>
_SELECT_

done

# Now over-write the jingleSelect file.

if mv /var/www/html/elements/jinglesSelect.TMP /var/www/html/elements/jinglesSelect.txt
then
  printf "\n$(timestamp) Jingle Added, and options updated. " >> /home/sbadmin/sb.log
else
  printf "\n$(timestamp) No Jingles Found! " >> /home/sbadmin/sb.log
  report "Jingles Missing" "JingleUpload was executed and found zero jingles."
fi

exit 0
