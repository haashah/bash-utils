#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo 'please specify ip of DNS server as argument'
  exit 1
fi
ip=$1
for x in {1..5}; do
     echo "Running iteration # ${x}"
     resperf-report -s $ip -d queryfile-example-current
done  
 
