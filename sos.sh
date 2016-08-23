#!/bin/bash -x

# This script should only be executed by the sos.ph counterpart, and when run it should try to send an email to all support people.
#+ If it gets an email through successfully, exit 0, else 1

username="$(ip addr show eth0 | grep link/ether | awk '{print $2}' | sha1sum | awk '{print $1}')"
ftpmasterlog="/home/sbadmin/ftpLOG"
conf="/home/sbadmin/sb.conf"
WPATH="/home/sbadmin"
ip="$(ip addr show eth0 | grep inet | grep global | awk '{print $2}')"


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


################## CONSTS #####################################

supportPersonOne="tim@base-it-systems.com"
supportPersonTwo="info@silver-box.co.za"

################# Main Script #################################

#sleep 3
#exit 0

# Try sending to one person first:

if $WPATH/sendEmail-v1.56/sendEmail \
-f reports@base-it-systems.com \
-xu reports@base-it-systems.com \
-xp Ziggystardust46211 \
-s 188.121.53.3:80 -o tls=no \
-t "$supportPersonOne" \
-u "SOS from $username" \
-m "SOS Signal was sent at $(timestamp)."
then
  es1="0"
else
  es1="1"
fi

# Now to the second person:
if $WPATH/sendEmail-v1.56/sendEmail \
-f reports@base-it-systems.com \
-xu reports@base-it-systems.com \
-xp Ziggystardust46211 \
-s 188.121.53.3:80 -o tls=no \
-t "$supportPersonTwo" \
-u "SOS from $username" \
-m "SOS Signal was sent at $timestamp()."
then
  es2="0"
else
  es2="1"
fi

if [ "$es1" == 0 ] && [ "$es2" == 0 ]
then
  exit 0
elif [ "$es1" == 1 ] && [ "$es2" == 1 ]
then
  exit 1
else
  exit 2
fi

