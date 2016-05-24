#/bin/bash

# This is the primary function for the silver-box on site microserver (RPi)
# The function should check if the config file exists, and use it to get the playlists from the central server
#+ and make sure the Library has all the files as per latest playlists.txt lists.

# Username on central server is MAC through hashing.

# Program will run at startup, and once per day during down-time.

# Errors Breakdown:
#+ ERR1 relates to the Config INI file. Error message will always be descriptive, and accompanied with a report sent to Admin.
#+ ERR2 relates to the PlayList.

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
ftpmasterlog="/home/sbadmin/ftpLOG"
conf="/home/sbadmin/sb.conf"
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


confCHK()
{
	confchk="NOT-OK"
  if [ ! -s $conf ]
  then
    printf "Conf-Missing" > /home/sbadmin/ERR1.stat
    if getConf
    then
      printf "OK" > /home/sbadmin/ERR1.stat
      printf "\n$(timestamp) Config Received" >> /home/sbadmin/sb.log
    else
      printf "Failed to Retrieve, Exiting... $(timestamp)" > /home/sbadmin/ERR1.stat
      printf "\n$(timestamp) Failed to retrieve Config" >> /home/sbadmin/sb.log
      report "Failed To Get CONF" "Tried to retrieve the conf file, but couldn't. $(timestamp) \n $(cat $ftplogConf)"
      printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/sb.log
      printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/playlist.log
      printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>$ftpmasterlog
      exit 2
    fi
  fi

  epochNow="$(date +%s)"
  epochConf="$(awk -F ' = ' '/epoch/ {print $2}' $conf)"
  confUser="$(awk -F ' = ' '/ID/ {print $2}' $conf)"
  # Check if the conf file is fresh
  if [ "$((epochNow - epochConf))" -gt "86400" ]
  then
    printf "Conf older than 24h $(timestamp)" > /home/sbadmin/ERR1.stat
    printf "\n$(timestamp) Conf older than 24h" >> /home/sbadmin/sb.log
    if getConf
    then
      confchk="OK"
    else
      printf "\nFailed to Retrieve, Exiting... $(timestamp)" >> /home/sbadmin/ERR1.stat
      printf "\n$(timestamp) Failed to retrieve Config" >> /home/sbadmin/sb.log
      report "Failed To Get CONF" "Tried to retrieve the conf file, but couldn't. $(timestamp) \n $(cat $ftplogConf)"
      printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/sb.log
      printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/playlist.log
      printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>$ftpmasterlog
      exit 3
    fi
  # Provided the conf file is either fresh, or is the freshest there is available, check if the username is correct.
  elif [ "$confUser" != "$username" ]
  then
    printf "\n$(timestamp) Invalid Username in Config" >> /home/sbadmin/sb.log
    printf "\nInvalid Username in Config $(timestamp)" >> /home/sbadmin/ERR1.stat
    report "Invalid Config File" "According to sb.conf: $confUser"
    printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/sb.log
    printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/playlist.log
    printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>$ftpmasterlog
    exit 1
  else
  confchk="OK"
  fi

}

getConf()
{
  # FTP to central and get the conf file.
  ftplogConf="/home/sbadmin/ftplogGetConf"

ftp -i -v silver-box.co.za << _DOWNLOAD_ >$ftplogConf
cd CONF
get "$username.conf" sb.conf
bye
_DOWNLOAD_

  grep "226-File successfully transferred" $ftplogConf
  if [ $? != 0 ]
  then
    F101=fail
    cat $ftplogConf >> $ftpmasterlog
  else
    F101=ok
    cat $ftplogConf >> $ftpmasterlog
    rm $ftplogConf
  fi

  if [ "$F101" = "ok" ]
  then
    return 0
  else
    return 1
  fi

}

getList()
{
  # FTP into the central server and get the playlists according to the latest on in conf file, which is comma separated list.
  list="$(awk -F ' = ' '/currentPlaylist/ {print $2}' $conf)" # Grabs the list of playlists.
  echo "$list" | tr "," "\n" >$WPATH/All-lists

  while read line
  do
    ftplogList="/home/sbadmin/ftplogGetList"

ftp -i -v silver-box.co.za << _DOWNLOAD_ >$ftplogList
cd CONF
get "$line" "$line"
bye
_DOWNLOAD_

    grep "226-File successfully transferred" $ftplogList
    if [ $? != 0 ]
    then
      printf "\n$(timestamp) Couldn't get Playlist" >> /home/sbadmin/sb.log
      printf "Couln't get Playlist $(timestamp) - Should be $line" > /home/sbadmin/ERR2.stat
      report "Failed to get PlayList" "List should be: $line \n $(cat $ftplogList)"
      cat $ftplogList >> $ftpmasterlog
    else
      printf "OK" > /home/sbadmin/ERR2.stat
      printf "\n$(timestamp) Got Playlist $line" >> /home/sbadmin/sb.log
      cat $ftplogList >> $ftpmasterlog
      rm $ftplogList
    fi
  done <$WPATH/All-lists

  return "$?"
}

propagate()
{
  # Compare the new playlists which have been downloaded already from conf file with the current channels directory,
  #+ then download any files that are not in the LIBRARY/

  # First Remove the NO_CHANNEL file if is exists
  rm $WPATH/channels/NO_CHANNELS


  # Loop through all playlists one by one.
  while read playlist
  do
    # First create a list of files in the PLAYLIST/ & LIBRARY/ directory
    playlistName="${playlist%.*}"
    ls -1 $WPATH/LIBRARY/ >$WPATH/libraryList
      listLibrary="$WPATH/libraryList" # Get a text list if the entire library to compare to.
    # Now edit the new playlist to remove empty lines and malformed file names:
    sed  '/[^-A-Za-z0-9.\x27() ]/d;/''/d;/^\s*$/d' $WPATH/"$playlist"  >$WPATH/channels/$playlistName
    listNew="$WPATH/channels/$playlistName" # Place the formatted playlist in the channels directory to become a usable channel.

    # Now loop new playlist through LIBRARY and shedule download of missing tracks.
    while read line
    do
      if grep -x "$line" "$listLibrary"
      then
        printf "\n$(timestamp) $line Already in Library" >>/home/sbadmin/playlist.log
      else
        printf "\n$(timestamp) $line Not in Library - Added to Wish-List" >>/home/sbadmin/playlist.log
        # File is on PlayList, but not in the Library, so schedule download.
        printf "$line\n" >>/home/sbadmin/wishList
      fi
    done <"$listNew"

    queue="/home/sbadmin/wishList"

    # Now download files one by one and report any problems, if there are any downloads necessary...

    if [ -f "$queue" ]
    then
      while read line
      do
        ftplogSong="/home/sbadmin/ftplogGetSong"
ftp -i -v silver-box.co.za << _DOWNLOAD_ >$ftplogSong
cd MUSIC
get "$line"
bye
_DOWNLOAD_

        if grep "226-File successfully transferred" $ftplogSong && [ -s $line ]
        then
          printf "\n$(timestamp) Downloaded File: $line from FTP Server " >> /home/sbadmin/playlist.log
          if mv "$line" /home/sbadmin/LIBRARY
	  then
	    printf "\n$(timestamp) Copied File: $line to LIBRARY " >> /home/sbadmin/playlist.log
	  else
	    rm "$line"
	    printf "\n$(timestamp) Couln't copy File: $line to Library " >> /home/sbadmin/playlist.log
	    printf "\n$(timestamp) WARNING! Couln't copy File: $line to Library " >> /home/sbadmin/sb.log
	  fi
        else
	    rm "$line"
            printf "\nCouln't get File: $line from FTP server $(timestamp)" >> /home/sbadmin/ERR2.stat
            printf "\n$(timestamp) WARNING! Couln't get File: $line from FTP Server " >> /home/sbadmin/sb.log
            printf "\n$(timestamp) Couln't get File: $line from FTP Server " >> /home/sbadmin/playlist.log
        fi
          cat $ftplogSong >> $ftpmasterlog
          rm $ftplogSong

      done <"$queue"

        rm "$queue"
    else
      printf "\n$(timestamp) No downloads required for $playlistName, all files present locally. " >> /home/sbadmin/playlist.log
      printf "\n$(timestamp) No downloads required for $playlistName, all files present locally. " >> /home/sbadmin/sb.log
    fi

    # Clean up
    rm $listLibrary

    printf "$playlistName\n" >>$WPATH/NEWchannels-list

  done <$WPATH/All-lists

  # Now check if the box is currently playing a channel that still exists, and change if not.
  #+ Then remove the old channels.

  if ! grep "$(cat $WPATH/CHANNEL)" $WPATH/NEWchannels-list || [ ! -s $WPATH/CHANNEL ]  # If the current channel no longer exsists.
  then
    printf "$(head -1 $WPATH/NEWchannels-list)" >$WPATH/CHANNEL # Switch channel the first channel available.
  fi

  while read channel
  do
    if ! grep $channel $WPATH/NEWchannels-list # Old channel no longer exists.
    then
      rm -R $WPATH/channels/$channel # Remove the channel's playlist from directory, so it is no longer an option in UI
      [ -f $WPATH/$channel.QB ] && rm $WPATH/$channel.QB # Also remove the channels backedup queue, if it exists.
    fi
  done <$WPATH/channels-list

  $WPATH/channelBox.sh "$(cat $WPATH/CHANNEL)" # Force the re-write of channel options on the UI

  $WPATH/jingleUpload.sh # Force the re-write of jingles option list.

  sudo mv --force $WPATH/NEWchannels-list $WPATH/channels-list
  rm $WPATH/All-lists $WPATH/*.txt
}

#################### End of FUNCTIONS ######################################



	###  Main Procedure ###

printf "\n\n\n----------- $(timestamp) BEGIN PRIMARY ------------\n\n\n" >>/home/sbadmin/sb.log
printf "\n\n\n----------- $(timestamp) BEGIN PRIMARY ------------\n\n\n" >>/home/sbadmin/playlist.log
printf "\n\n\n----------- $(timestamp) BEGIN PRIMARY ------------\n\n\n" >>$ftpmasterlog

# First check config:

confCHK

if [ "$confchk" = "OK" ]
then
  # Get latest list
  if getList
  then
    propagate
  else
    report "Failed to get PlayLists" "Can't continue to propagate."
  fi
else
  printf "\n$(timestamp) WARNING! Config Check Failed, and somehow didn't shut down the program properly." >> /home/sbadmin/sb.log
  report "Config Failure" "Config check failed, but somehow didn't shut down the program properly."
  printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/sb.log
  printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/playlist.log
  printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>$ftpmasterlog
  exit 4
fi

  printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/sb.log
  printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>/home/sbadmin/playlist.log
  printf "\n\n\n----------- $(timestamp) END PRIMARY ------------\n\n\n" >>$ftpmasterlog

exit 0
