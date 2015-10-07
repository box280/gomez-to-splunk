## gomez-to-splunk
Make API Calls to Gomez and convert this into something Splunk friendly.
Written in Bash because thats the scripting language I'm best at...

G'day. These scripts are designed for customers of Dynatrace/Gomez Synthetic Monitoring or End User management products. I'm unsure of what the real name of the product is as the company has changed names and products often recently - they may even be renamed keynote in the future. Anyway - we tend to call this software "Gomez" as it's a cooler name...

At a high level the scripts/configs undertake actions below
(1) make a call to the dynatrace API http://gpn.webservice.gomez.com. Download a chunk of data locally
(2) process the downloaded data into a (a) summary of the Gomez tests (b) a detail of the objects that were tested
(3) the processed data is in a splunk friendly location and a splunk friendly format ready for ingestion.


## INSTALL?

Yes. Please do.

Pre-requisites include
- ability to decipher my notes and thoughts
- bash - Tested on CentOS 6, bash version 4.1
- splunk - tested on splunk v 6.2 and above
- the xml_pp (perl-XML-Twig rpm package) and xpath (perl-XML-XPath rpm package) commands are available.

# gomez scripts
The pullgomezapibulk.sh and gomezconversion-object.sh script are assumed to be installed in /usr/box280 - but these locations can easily be changed

The following files exist in this repository
- /usr/box280/bin/pullgomezapibulk.sh
- /usr/box280/bin/gomezconversion-object.sh
- /usr/box280/bin/convertobject.sh
- /usr/box280/etc/closedatafeed.xml
- /usr/box280/etc/getresponsedata.xml
- /usr/box280/etc/opendatafeed.xml
- /opt/splunkforwarder/etc/apps/gomez/default/inputs.conf


The following directories are assumed to be created
- SOURCEXML=/usr/box280/etc                             * where the xml files/template for the SOAP call to Gomez reside
- TMPXML=/usr/box280/tmp                                * where the temporary edited xml files for SOAP calls to Gomez sit
- SCRIPTLOG=/var/log/box280/pullgomezdatafromapi.log    * where the log files from the script are kept
- RESPONSEDIR=/home/gomez/source-api                    * where the gomez source data is stored when pulled from the API
- /tmp                                                  * where some files are occassionally written to
- OUTPUTDIR=/home/gomez/splunk-api                      * where the splunk friendly step summary files are written to
- OBJECTLOGDIR=/home/gomez/splunk-api/object            * where splunk friendly object detail logs are stored


##  Execute the script

You only ever need to invoke one of the scripts. For help invoke the command below:
- /usr/box280/bin/pullgomezapibulk.sh -h 

An example script execution - to get 10 minutes of data ending at 1:20AM UTC the 9th of July 2015 
- /usr/box280/bin/pullgomezapibulk.sh -e "2015-07-09 01:20:00" -d 10

The script - /usr/box280/bin/pullgomezapibulk.sh
- calls /usr/box280/bin/gomezconversion-object.sh
- which then calls /usr/box280/binconvertobject.sh

## Splunk Config
A sample splunk input.conf file is available for your reading pleasure :)
