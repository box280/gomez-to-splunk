#!/bin/bash
# This script will pull data from the Gomez API using SOAP.... 

PID=$( echo $$ )
SOURCEXML=/usr/box280/etc
TMPXML=/usr/box280/tmp
OPENDATAFEEDRESPONSE=$TMPXML/opendatafeedresponse.log-$PID
CLOSEDATAFEEDRESPONSE=$TMPXML/closedatafeedresponse.log-$PID
SCRIPTLOG=/var/log/box280/pullgomezdatafromapi.log
USERENDTIME=$1
RESPONSEDIR=/home/gomez/source-api

#generate start and end time
function fn_generate_times() {
	if [ "$USERNOW" -eq 1 ] ; then
		echo INFO\: user wants the end time of the data to be now > /dev/null
		date_xm_ago=$( date "+%Y-%m-%d %H:%M:00"  -d "$USERDURATION mins ago" -u )
		date_end_minute=$( date "+%Y-%m-%d %H:%M:00" -u )
		date_xm_ago_short=$( date "+%Y%m%d_%H%M00"  -d "$USERDURATION mins ago" -u )
		date_end_minute_short=$( date "+%Y%m%d_%H%M00" -u )
	else
		echo INFO\: user did not want recent data - they may have specified a time > /dev/null
		if  [ -z "$USEREND" ] ; then
			echo ERROR\: hey - you did not specify what end time you want - please use the -h option to show a help screen
			exit
		else
			date_xm_ago=$( date -d "$USEREND UTC-$USERDURATION minutes" +%Y-%m-%d\ %H:%M:00 -u )
			date_end_minute=$( echo $USEREND | sed "s/..$/00/g" )
			date_xm_ago_short=$( TZ=UTC date -d "$date_xm_ago" +%Y%m%d_%H%M00 )
			date_end_minute_short=$( TZ=UTC date -d "$USEREND" +%Y%m%d_%H%M00 )
			date_yyyymmdd=$( echo $date_end_minute | awk -F' ' '{print $1}' | sed "s/-//g" )
		fi
	fi
}

function fn_date_now () {
	datenow=$( date )

}


function fn_help () {
	echo This script will connect to the gomez\/dynatrace API and pull in data from a time period relative to now
	echo "usage: pullgomezapibulk [ -e \"yyyy-mm-dd HH:MM:SS\" ] [ -d minutes ] [ -n ]"
	echo -e "\n"
	echo "-e: end time. Please use double quotes \" around the date/time"
	echo "-d: duration in minutes"
	echo "-n: the end time is now! do NOT use the -n flag in conjunction with the -e flag"
	echo Please use double quotes \" around the date/time format for parameter -e


}

# LOGIC STARTS HERE


# The bit below here will check the options that were passed to the script 
OPTIND=1         # Reset in case getopts has been used previously in the shell.

output_file=""
USERVERBOSE=0
USERNOW=0

while getopts "h?e:d:n:" opt; do
    case "$opt" in
    h|\?)
        fn_help
        exit 0
        ;;
    e)
	USEREND=$OPTARG
	;;
    d)
	USERDURATION=$OPTARG
	;;
    n)
	USERNOW=1
	;;
    v)
	USERVERBOSE=1
	;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

# display variables if verbose mode -v is set
if [ "$USERVERBOSE" -eq 1 ] ; then
	echo "verbose=$VERBOSE, USEREND='$USEREND', USERDURATION="$USERDURATION", USERNOW="$USERNOW", Leftovers: $@"
fi

fn_generate_times
DATAFEEDRESPONSE=$RESPONSEDIR/response-"$date_xm_ago_short"-"$date_end_$date_end_minute_short".xml
echo the date_yyyymmdd is $date_yyyymmdd
echo date_xm_ago = $date_xm_ago
echo date_xm_ago_short = $date_xm_ago_short
echo date_end_minute = $date_end_minute
echo $DATAFEEDRESPONSE


fn_date_now
echo INFO\: \["$PID"\] starting script at $datenow >> $SCRIPTLOG
echo INFO\: \["$PID"\] getting data from $date_xm_ago until $date_end_minute >> $SCRIPTLOG
echo INFO\: \["$PID"\] writing data to $DATAFEEDRESPONSE

# copy source xml to tmp location
rm -fv $TMPXML/*.xml*
rm -fv $OPENDATAFEEDRESPONSE
find /tmp -type f -iname "*.log-*" -exec rm -fv {} \;
cp $SOURCEXML/opendatafeed.xml $TMPXML/opendatafeed.xml-$PID
cp $SOURCEXML/getresponsedata.xml $TMPXML/getresponsedata.xml-$PID
cp $SOURCEXML/closedatafeed.xml $TMPXML/closedatafeed.xml-$PID


# now change the start time and end time
sed -i  "s/STARTTIME/$date_xm_ago/" $TMPXML/opendatafeed.xml-$PID 
sed -i  "s/ENDTIME/$date_end_minute/" $TMPXML/opendatafeed.xml-$PID

cd $TMPXML

# now initiate a data trasnfer
echo INFO\: establishing a connection to http://gpn.webservice.gomez.com/DataExportService60/GPNDataExportService.asmx  >> $SCRIPTLOG 
echo INFO\: establishing a connection to http://gpn.webservice.gomez.com/DataExportService60/GPNDataExportService.asmx - response is in file $OPENDATAFEEDRESPONSE
curl -X POST -H "Content-Type: text/xml; charset=utf-8" -H "SOAPAction: http://gomeznetworks.com/webservices/OpenDataFeed2" --data-binary @opendatafeed.xml-"$PID" http://gpn.webservice.gomez.com/DataExportService60/GPNDataExportService.asmx -o $OPENDATAFEEDRESPONSE


# now get the session token
status=$( xpath $OPENDATAFEEDRESPONSE //OpenDataFeed2Response/GpnOpenUtaDataFeedResponse/Status/eStatus  | awk -F'>' '{print $2}' | awk -F'<' '{print $1}' )
if [ "$status" == "STATUS_SUCCESS" ] ; then
	sessiontoken=$( xpath $OPENDATAFEEDRESPONSE //GpnOpenUtaDataFeedResponse/SessionToken | awk -F'>' '{print $2}' | awk -F'<' '{print $1}' )
	echo INFO\: \["$PID"\] GOOD status code - session token is $sessiontoken
	echo INFO\: \["$PID"\] GOOD status code - session token is $sessiontoken >> $SCRIPTLOG

else
	echo ERROR\: \["$PID"\] bad status returned by Gomez - status code was $status >> $SCRIPTLOG
	echo ERROR\: \["$PID"\] bad status returned by Gomez - status code was $status
	exit
fi

#now put the session token into the get data request AND the closesession request
sed -i "s/SESSIONTOKENHERE/$sessiontoken/" $TMPXML/getresponsedata.xml-$PID
sed -i "s/SESSIONTOKENHERE/$sessiontoken/" $TMPXML/closedatafeed.xml-$PID

# get the data
fn_date_now
echo INFO\: attempting to pull data from gpn.webservice.gomez.com to $DATAFEEDRESPONSE at $datenow
curl -X POST -H "Content-Type: text/xml; charset=utf-8" -H "SOAPAction: http://gomeznetworks.com/webservices/GetResponseData" --data-binary @getresponsedata.xml-$PID http://gpn.webservice.gomez.com/DataExportService60/GPNDataExportService.asmx -o $DATAFEEDRESPONSE

# check status code from the response
response_status=$( xpath $DATAFEEDRESPONSE //GpnResponseData/Status/eStatus | awk -F'>' '{print $2}' | awk -F'<' '{print $1}' )
if [ "$response_status" == "STATUS_SUCCESS" ] ; then
	echo INFO\: \["$PID"\] we got a good status. Continue with the script please
else
	echo ERROR\: \["$PID"\] Gomez did NOT reply with a  favourable status - the response was $response_status - exiting script now
	fn_date_now
	echo ERROR\: \["$PID"\] Gomez did NOT reply with a  favourable status - the response was $response_status - exiting script now at $datenow >> $SCRIPTLOG
	exit
fi

# close the session
echo INFO\: \["$PID"\] closing the session for $sessiontoken - output in closedatafeed.xml-$PID
curl -X POST -H "Content-Type: text/xml; charset=utf-8" -H "SOAPAction: http://gomeznetworks.com/webservices/CloseDataFeed" --data-binary @closedatafeed.xml-$PID http://gpn.webservice.gomez.com/DataExportService60/GPNDataExportService.asmx -o $CLOSEDATAFEEDRESPONSE

fn_date_now
echo INFO\: about to convert the gome data to something splunk can use at $datenow >> $SCRIPTLOG
echo INFO\: about to convert the gome data to something splunk can use at $datenow
echo -e "\n" >> $SCRIPTLOG

# remove old source files older than 1 day old
find  $RESPONSEDIR -type f -iname "*response-*.xml" -mtime +1 -exec rm -fv {} \;

#making an extra copy - maybe unnecessary
cp $DATAFEEDRESPONSE /tmp/original-data-"$date_xm_ago_short"-"$date_end_minute_short".xml
find /tmp -type f -iname "*original-data*" -mmin +60 -exec rm -fv {} \;

# all files in $RESPONSEDIR are now iconv data - NOT the original downloaded data 
iconv -f latin1 -t ascii//TRANSLIT $DATAFEEDRESPONSE > /tmp/response-"$date_xm_ago_short"-"$date_end_minute_short".xml
rm -fv $DATAFEEDRESPONSE
cp  /tmp/response-"$date_xm_ago_short"-"$date_end_minute_short".xml $DATAFEEDRESPONSE

/usr/box280/bin/gomezconversion-object.sh $DATAFEEDRESPONSE $date_yyyymmdd 
