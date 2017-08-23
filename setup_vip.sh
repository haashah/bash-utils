#!/bin/bash

# VIRTUAL IPS CREATOR
#
# Script to setup virtual ips and then configure PowerDNS to bind to all of those ifcs
# We use the first interface on the machine for this purpose. Using AWK parse ip address, subnet mask and last octet
# Then for each interface we increment last octet and dynamically assign each subinterface a new ip

# Author: Hammad Shah
# 2017


function cleanup {

  ifc_name=$1
  for x in $(seq 1 $num_ifcs); do
    echo "cleaning up interface $ifc_name:$x"
    ifconfig $ifc_name:$x down  
  done

}

#DEFAULT ARG VALUES
num_ifcs=1
file_path="/etc/powerdns/recursor.conf"
cleanup=false
ifc=$(ip route get 8.8.8.8 | awk '/dev/ {print $5}')

for i in "$@"; do
	case $i in
		-n=*|--numifcs=*)
		num_ifcs="${i#*=}"
		shift # past argument=value
		;;
		-fp=*|--filepath=*)
		file_path="${i#*=}"
		shift # past argument=value
		;;
		-c|--cleanup)
		cleanup=true
		shift # past argument=value
		;;
        -i=*|--interface=*)
        ifc="${i#*=}"
        shift
        ;;
		*)
		echo "Unknown parameter $i"        # unknown option
		exit 1
		;;
	esac
done
  
ip_addr=$(ip -o -f inet addr show | awk '/'$ifc'/ {print $4}')
three_octets=$(echo $ip_addr | awk 'BEGIN {FS="[./]";} {print $1"."$2"."$3"."}')
last_octet=$(echo $ip_addr | awk 'BEGIN { FS="[./]"; } {print $4}')
mask=$(echo $ip_addr | awk 'BEGIN { FS="[./]";} {print $5}')
declare -a list_ips=()
list_ips+=($three_octets$last_octet)
if [[ "$cleanup" == true ]]; then
  cleanup $ifc
  exit 0
fi
echo -e "\n\n------- CREATING VIPS ---------\n\n"
for x in $(seq 1 $num_ifcs); do
  echo "Adding sub interface #$x"
  last_octet=$(($last_octet+1))
  new_ip=$three_octets$last_octet"/"$mask
  echo "Assigning new ip address: $new_ip"
  list_ips+=($three_octets$last_octet)
  ifconfig $ifc:$x $new_ip 
  if [[ $? -ne 0 ]]; then
    echo 'ERROR: Failed to create subinterface'
    exit 1
  fi
done

#echo "DEBUG: list of ips ${list_ips[*]}"

# time to add values to powerDNS config file
echo "Changing powerDNS config with new virtual ips"
sed -i "s/\(local-address *= *\).*/\1${list_ips[*]}/" $file_path 

# restart powerDNS service
echo "Restarting powerDNS service"
systemctl restart pdns-recursor

sleep 3


if [[ $? -ne 0 ]]; then
  echo 'powerDNS failed to restart'
  exit 1
fi

echo -e "\n\n------- SETUP DONE ----------"
