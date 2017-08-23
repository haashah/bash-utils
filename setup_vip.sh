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

if [[ $# -lt 1 ]]; then
  echo 'invalid number of arguments. Must mention number of interfaces to create or cleanup with --cleanup flag'
  echo 'usage: e.g  sudo ./setup-vip.sh 5, sudo ./setup-vip.sh --cleanup'
  exit 1
elif [[ $# -eq 2 ]]; then
  num_ifcs=$1
  cleanup=true
else
  num_ifcs=$1
  cleanup=false
fi
ifc=$(ip route get 8.8.8.8 | awk '/dev/ {print $5}')
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
for x in $(seq 1 $num_ifcs); do
  echo "adding sub interface #$x"
  last_octet=$(($last_octet+1))
  echo $last_octet
  new_ip=$three_octets$last_octet"/"$mask
  list_ips+=($three_octets$last_octet)
  echo "new ip_addr value: $new_ip"
  ifconfig $ifc:$x $new_ip 
  if [[ $? -ne 0 ]]; then
    echo 'Failed to create subinterface'
    exit 1
  fi
done

#echo "DEBUG: list of ips ${list_ips[*]}"

# time to add values to powerDNS config file
sed -i "s/\(local-address *= *\).*/\1${list_ips[*]}/" /etc/powerdns/recursor.conf

# restart powerDNS service
systemctl restart pdns-recursor

if [[ $? -ne 0 ]]; then
  echo 'powerDNS failed to restart'
  exit 1
fi


