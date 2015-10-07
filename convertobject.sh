#!/bin/bash
TESTNUM=$1
STEPNUM=$2
OBJECTNUM=$3
SOURCEFILE=$4
PID2=$( echo $$ )
OBJECTLOGDIR=/home/gomez/splunk-api/object

echo INFO\: \[$PID2\] object script is processing test $TESTNUM step $STEPNUM object $OBJECTNUM from $SOURCEFILE
data=$( xpath $SOURCEFILE //GpnResponseData/TXTEST[$TESTNUM]/PAGE[$STEPNUM]/OBJECT[$OBJECTNUM] )
objectrc=$( echo $data | awk -F'rc=' '{print $2}' | awk -F'"' '{print "\"" $2"\""}' )
objectrtime=$(  echo $data | awk -F'rtime=' '{print $2}' | awk -F'"' '{print "\"" $2"\""}' )
otime=$( echo $data | awk -F'fbstart=' '{print $2}' | awk -F'"' '{print $2}' )
objectfbtime=$( echo $data |  awk -F'fbtime=' '{print $2}' | awk -F'"' '{print "\"" $2"\""}' )
uhost=$(  echo $data | awk -F'uhost=' '{print $2}' | awk -F'"' '{print "\"" $2"\""}' )
upage=$(  echo $data | awk -F'upage=' '{print $2}' | awk -F'"' '{print "\"" $2"\""}' )
uparam=$( echo $data | awk -F'uparam=' '{print $2}' | awk -F'"' '{print "\"" $2"\""}' )

# the otime in the payload of the gomez data will determine which log to be written to
logfilename=$( echo $otime | awk -F' ' '{print $1}' | sed "s/-//g" | sed "s/^/objectsummary-/g" | sed "s/$/\.log/g" )
logfile=$OBJECTLOGDIR/$logfilename

echo otime=\"$otime +0000\" mid=\"$mid\" sid=\"$sid\" popname=\"$popname\" prreg=\"$prreg\" prisp=\"$prisp\" country=\"$country\" city=\"$city\" carrier=\"$carrier\" network_type=\"$network_type\" objectrc=$objectrc objectrtime=$objectrtime objectfbtime=$objectfbtime uhost=$uhost upage=$upage uparam=$uparam >> $logfile

echo INFO\: \[$PID2\] Finsihed processing the object 
