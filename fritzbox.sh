#!/bin/bash

FritzBoxAddr="192.168.0.1"
UpnpPort="49000"

getExternalIP=true
getDslSpeeds=true
getUploadDownloadTotal=true
getDslInformation=false

LOCK_FILE=/tmp/fritxbox.tmp

show_help () {
echo "This script will fetch data from the FritxBox and make it Human or Cacti readeble.
Syntax is fritxbos.sh -h?Hv

	-h, or ?	for this help
	-H	will generate Human output
	-v	verbose output from SOAP Calls
	-c	check Fritzbox Connectivity

By Georgiy Sitnikov."
}

UpnpSoapCall () {

wget -qO- --timeout=2 --tries=2 "http://$FritzBoxAddr:$UpnpPort/igdupnp/control/$serviceId" \
--header "Content-Type: text/xml; charset="utf-8"" \
--header "SoapAction:urn:schemas-upnp-org:service:$serviceType:1#$action" \
--post-data="<?xml version='1.0' encoding='utf-8'?> \
<s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'> \
<s:Body> \
<u:$action xmlns:u='urn:schemas-upnp-org:service:$serviceType:1' /> \
</s:Body> \
</s:Envelope>" > $LOCK_FILE

    if [ "$?" -gt "0" ]; then
		echo Connection Problems, please check settings.
        exit 1
	fi
}

checkFritxbox () {
	wget -qO- --timeout=2 --tries=2 "http://$FritzBoxAddr:$UpnpPort/igddesc.xml" | sed -n 's/^.*<\(friendlyName\)>\([^<]*\)<\/.*$/\2/p'
    if [ "$?" = "0" ]; then
		echo Found!
	else
		echo Not found. Connection Problems, please check settings.
	fi
}
getExternalIPSettings () {
	# Get External IP Address
	serviceId="WANIPConn1"
	serviceType="WANIPConnection"
	action="GetExternalIPAddress"
}

getDslSpeedsSettings () {
	# Get DSL Max Upload and Donwload Speeds
	serviceId="WANCommonIFC1"
	serviceType="WANCommonInterfaceConfig"
	action="GetCommonLinkProperties"
}

getUploadDownloadTotalSettings () {
	# Get Uploads and Donwloads
	serviceId="WANCommonIFC1"
	serviceType="WANCommonInterfaceConfig"
	action="GetAddonInfos"
}

getDslInformationSettings () {
	# Get Uploads and Donwloads
	serviceId="WANDSLInterfaceConfig1"
	serviceType="WANDSLIfConfig-com"
	action="GetInfo"
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
output_file=""
verbose=0

while getopts "h?Hvc" opt; do
	case "$opt" in
	h|\?)
		show_help
		exit 0
		;;
	H)
		human=1
		;;
	v)
		verbose=1
		;;
	c)
		checkFritxbox
		exit 0
		;;
	esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

if [ "$getExternalIP" = true ]; then

	getExternalIPSettings
	UpnpSoapCall
	[[ "$human" = 1 ]] && echo External IP: $(cat $LOCK_FILE | sed -n 's/^.*<\(NewExternalIPAddress\)>\([^<]*\)<\/.*$/\2/p')
    [[ "$verbose" = 1 ]] && cat $LOCK_FILE

fi

if [ "$getDslSpeeds" = true ]; then

	getDslSpeedsSettings
	UpnpSoapCall
	[[ "$human" = 1 ]] && echo Upload: $(echo $(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1UpstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p') / 1000000 | bc) Mbit/s
	[[ "$human" = 1 ]] && echo Download: $(echo $(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1DownstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p') / 1000000 | bc) Mbit/s
	[[ "$verbose" = 1 ]] && cat $LOCK_FILE
	#For Cacti
	DslSpeedUpload=$(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1UpstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p')
	DslSpeedDownload=$(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1DownstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p')

fi

if [ "$getUploadDownloadTotal" = true ]; then

	getUploadDownloadTotalSettings
	UpnpSoapCall
	[[ "$human" = 1 ]] && echo Upload: $(cat $LOCK_FILE | sed -n 's/^.*<\(NewTotalBytesSent\)>\([^<]*\)<\/.*$/\2/p') bytes
	[[ "$human" = 1 ]] && echo Download: $(cat $LOCK_FILE | sed -n 's/^.*<\(NewTotalBytesReceived\)>\([^<]*\)<\/.*$/\2/p') bytes
    [[ "$verbose" = 1 ]] && cat $LOCK_FILE
	#For Cacti
	UploadTotal=$(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewTotalBytesSent\)>\([^<]*\)<\/.*$/\2/p')
	DownloadTotal=$(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewTotalBytesReceived\)>\([^<]*\)<\/.*$/\2/p')

fi

if [ "$getDslInformation" = true ]; then

	getDslInformationSettings
	UpnpSoapCall
	cat $LOCK_FILE
#	[[ "$human" = 1 ]] && echo Upload: $(echo $(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1UpstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p') / 1000000 | bc) Mbit/s
#	[[ "$human" = 1 ]] && echo Download: $(echo $(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1DownstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p') / 1000000 | bc) Mbit/s
#	[[ "$verbose" = 1 ]] && cat $LOCK_FILE
	#For Cacti
#	DslSpeedUpload=$(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1UpstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p')
#	DslSpeedDownload=$(cat ${LOCK_FILE} | sed -n 's/^.*<\(NewLayer1DownstreamMaxBitRate\)>\([^<]*\)<\/.*$/\2/p')

fi

[[ "$human" = 1 ]] || echo DslSpeedUpload:$DslSpeedUpload \
DslSpeedDownload:$DslSpeedDownload \
UploadTotal:$UploadTotal \
DownloadTotal:$DownloadTotal

rm $LOCK_FILE

exit 0
