#!/bin/bash
# This script will convert gomez xml data into something splunk can use

SOURCEFILE=/home/gomez/source-api/response-20150823_202000-20150823_202500.xml
DESTFILE=/tmp/kvck
LOGFILE=/var/log/shazamteam/convertgomez.log
LOGSTEPSUMMARY=/home/gomez/splunk-api/stepsummary.log
OUTPUTDIR=/home/gomez/splunk-api
USERFILE=$1
SCRIPTHOME=/usr/shazamteam/bin
PID=$( echo $$ )
USERSUPPLIEDDATE=$2

function fn_rev_date() {
	if [ -z $USERSUPPLIEDDATE ] ; then
		date_rev_date=$( date +%Y%m%d -u )
	else
		date_rev_date=$USERSUPPLIEDDATE
	fi
}

fn_rev_date
#LOGSTEPSUMMARY=/home/gomez/splunk-api/stepsummary-"$date_rev_date".log
LOGSTEPSUMMARY=/$OUTPUTDIR/stepsummary-"$date_rev_date".log
function fn_date_now() {
	datenow=$( date )
}

function fn_quantify_txtests() {
	# This function will count the number of tests in the $SOURCEFILE
	# number 2
	txtest_count=$(  xml_pp $SOURCEFILE  | grep "/TXTEST" | wc -l )
	echo INFO\: \["$PID"\] I count $txtest_count tests in this file >> $LOGFILE
	echo INFO\: \["$PID"\] I count $txtest_count tests in this file

	# write a small file for each test. This will speed the bulk load up

for (( u=1; u<=$txtest_count; u++ ))
do
	txtfile=/tmp/txtfile-"$PID"-txtest-$u
	echo INFO\: processing test $u out of $txtest_count
	echo INFO\: generating single test file for test $u in file $txtfile
	cat $SOURCEFILE | xml_pp | head -14 > $txtfile
	xpath $SOURCEFILE //GpnResponseData/TXTEST["$u"] >> $txtfile
	cat $SOURCEFILE | xml_pp | tail -n 6 >> $txtfile
	echo INFO\: finished generating single test file for test $u in file $txtfile
	fn_get_txttest_keys $u
	find /tmp -type f -iname "*txtfile-*txtest*" -mmin +60 -exec rm -fv {} \;
done
}


function fn_get_txttest_keys() {
	# this funciton will get the keys and values that we care about for the txtests
	# doing an xpath into xml_pp can cause bugs with special characters causes bugs
	# number 3

	txttest_num=$1
	echo INFO\: txttest_num is $txttest_num - reading from $txtfile into /tmp/txtestdata-$PID
	xpath $txtfile //GpnResponseData/TXTEST[1] > /tmp/txtestdata-$PID
	txttest_header=$( xml_pp /tmp/txtestdata-$PID | head -1 )
	echo INFO\: end txttest_header

	find /tmp -type f -iname "*txttestdata-*" -mmin +60 -exec rm -fv {} \;

	#echo $SOURCEFILE '//GpnResponseData/TXTEST["$txttest_num"]' 
	#echo $txttest_header
	# maybe I use the header to get the data - maybe it will speed things up
        mid=$( echo $txttest_header | awk -F'mid=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
        tname=$( echo $txttest_header | awk -F'tname=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
        sid=$( echo $txttest_header | awk -F'sid=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )

	popname=$( echo $txttest_header | awk -F'popname=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	prreg=$(echo $txttest_header | awk -F'prreg=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	test_nbyte=$( xpath $txtfile //GpnResponseData/TXTEST[1]/@nbyte | awk -F'=' '{print $2}' | sed "s|\"||g" )
	prisp=$( echo $txttest_header | awk -F'prisp=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	popid=$( echo $txttest_header | awk -F'sid=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	ttime=$( echo $txttest_header | awk -F'ttime=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	prip=$( echo $txttest_header | awk -F'prip=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g"  )

	country=$( echo $popname | awk -F' - ' '{print $1}' )
	city=$( echo $popname | awk -F' - ' '{print $2}' )
	carrier=$( echo $popname | awk -F' - ' '{print $3}' )
	network_type=$( echo $popname | awk -F' - ' '{print $4}' )

	echo mid=\"$mid\" tname=\"$tname\" sid=\"$sid\" popname=\"$popname\" prreg=\"$prreg\" test_nbyte=\"$test_nbyte\" prisp=\"$prisp\" popid=\"$popid\" ttime=\"$ttime +0000\" prip=\"$prip\"
	fn_date_now

	echo INFO\: \["$PID"\] converting txtest $txttest_num at $datenow >> $LOGFILE
	export mid=$mid
	export sid=$sid
	export popname=$popname
	export prreg=$prreg
	export prisp=$prisp
	export popid=$popid
	export prip=$prip
	export country=$country
	export city=$city
	export carrier=$carrier
	export network_type=$network_type
	fn_count_steps
}

function fn_count_steps() {
	# this funciton will count how many steps there are in the test
	# number 4

        #step_count1=$( xml_pp $SOURCEFILE //GpnResponseData/TXTEST["$txttest_num"] > /tmp/gomez_pretty-$PID )
	#step_count=$( xpath /tmp/gomez_pretty-$PID //GpnResponseData/TXTEST[1] | grep "/PAGE" | wc -l )

	echo INFO\: start step count for test $txttest_num using file $txtfile
	step_count=$( xpath $txtfile //GpnResponseData/TXTEST[1] | xml_pp | grep /"PAGE" | wc -l )
	echo INFO\: \["$PID"\] I count $step_count steps in this test number $txttest_num >> $LOGFILE
	echo INFO\: \["$PID"\] I count $step_count steps in this test number $txttest_num

	for (( s=1; s<=$step_count; s++ )) 
	do
		echo INFO\: About find the keys for step $s in test $txttest_num using $txtfile
		fn_get_step_keys $s
	done

	find /tmp -type f -iname "*gomez_pretty*" -mmin +60 -exec rm -fv {} \;  
}

function fn_get_step_keys() {
##################################################### errors here
	# nuber 5
	step_num=$1
	echo pname start
	echo INFO\: start to generate step counter
	step_header=$( xpath $txtfile //GpnResponseData/TXTEST[1]/PAGE[$step_num] | xml_pp | head -1 )
	echo INFO\: after generate step counter
	pname=$( echo $step_header | awk -F'pname=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_rc200=$( echo $step_header | awk -F'rc200=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
        step_rc300=$( echo $step_header | awk -F'rc300=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
        step_rc400=$( echo $step_header | awk -F'rc400=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_rc500=$( echo $step_header | awk -F'rc500=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
        step_rcnet=$( echo $step_header | awk -F'rcnet=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
        step_nbyte=$( echo $step_header | awk -F'nbyte=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_rtime=$( echo $step_header | awk -F'rtime=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_fbsum=$( echo $step_header | awk -F'fbsum=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_sslsum=$( echo $step_header | awk -F'sslsum=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_dnssum=$( echo $step_header | awk -F'dnssum=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )
	step_nobj=$( echo $step_header | awk -F'nobj=' '{print $2}' | awk -F'" ' '{print $1}' | sed "s/\"//g" )

	export pname=\"$pname\"

	echo pname=\"$pname\" step_rc200=\"$step_rc200\" step_rc300=\"$step_rc300\" step_rc400=\"$step_rc400\" step_rc500=\"$step_rc500\" step_rcnet=\"$step_rcnet\" step_nbyte=\"$step_nbyte\" step_rtime=\"$step_rtime\" step_fbsum=\"$step_fbsum\" step_sslsum=\"$step_sslsum\" step_dnssum=\"$dnssum\" step_nobj=\"$step_nobj\"

	fn_write_step_summary
	fn_count_objects
	# for every step - count the number of objects then parse the file and write a summary for each object
}

function fn_write_step_summary() {
	# this function will write out the summary data to a file
	# timsteamp for this record is the start time of the first object
	# number 6

	echo INFO\: writing data into $LOGSTEPSUMMARY for step $step_num in test $txttest_num
	step_time=$( xpath $txtfile //GpnResponseData/TXTEST[1]/PAGE[$step_num]/OBJECT[1]/@fbstart  | awk -F'=' '{print $2}' | sed "s|\"||g" )
	echo step_time=\"$step_time +0000\"  mid=\"$mid\" tname=\"$tname\" sid=\"$sid\" popname=\"$popname\" country=\"$country\" city=\"$city\" carrier=\"$carrier\" network_type=\"$network_type\" prreg=\"$prreg\" test_nbyte=\"$test_nbyte\" prisp=\"$prisp\" popid=\"$popid\" ttime=\"$ttime +0000\" prip=\"$prip\" step_num=\"$step_num\"  pname=$pname step_rc200=\"$step_rc200\" step_rc300=\"$step_rc300\" step_rc400=\"$step_rc400\" step_rc500=\"$step_rc500\" step_rcnet=\"$step_rcnet\" step_nbyte=\"$step_nbyte\" step_rtime=\"$step_rtime\" step_fbsum=\"$step_fbsum\" step_sslsum=\"$step_sslsum\" step_dnssum=\"$step_dnssum\" step_nobj=\"$step_nobj\" >> $LOGSTEPSUMMARY

}	

function fn_count_objects() {
	# number 7
	echo INFO\: startimg object count for test $txttest_num step $step_num
	object_count=$( xpath $txtfile //GpnResponseData/TXTEST[1]/PAGE[$step_num] | xml_pp | grep OBJECT| wc -l )
	 echo INFO\: I count $object_count for step $step_num
	
	for (( o=1; o<=$object_count; o++ ));
	do
		echo INFO\: offloading the object analysis for test $txttest_num step $step_num object $o from file $txtfile
	        #$SCRIPTHOME/convertobject.sh $txttest_num $step_num $o $SOURCEFILE &
		$SCRIPTHOME/convertobject.sh 1 $step_num $o $txtfile &
	done

}

### LOGIC STARTS HERE

fn_date_now
echo INFO\: \["$PID"\]  converting xml data to something splunk likes - started at $datenow >> $LOGFILE

if [ -z "$USERFILE" ] ; then
        echo INFO\: no user file supplied by the user > /dev/null
        echo INFO\: the source file to be used is $SOURCEFILE
        echo INFO\: the source file to be used is $SOURCEFILE >> $LOGFILE
else
        if [ -e "$USERFILE" ] ; then
                echo INFO\: making use of user supplied filename $USERFILE
                echo INFO\: making use of user supplied filename $USERFILE >> $LOGFILE
                SOURCEFILE=$USERFILE
        else
                echo ERROR\: Userfile $USERFILE does NOT exist. Exiting script >> $LOGFILE
                echo ERROR\: Userfile $USERFILE does NOT exist. Exiting script
                exit
        fi
fi

fn_quantify_txtests

#for (( t=1; t<=$txtest_count; t++ ))
#do 
#	fn_get_txttest_keys $t
#done

fn_date_now
echo INFO\: \["$PID"\] finished converting $SOURCEFILE at $datenow >> $LOGFILE
echo INFO\: \["$PID"\] I should be finished now
