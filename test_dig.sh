#!/bin/bash

if [[ $# -ne 2 ]]; then
  echo 'missing argument.exiting'
  echo './test_dig.sh    arg1=dns server ip    arg2=time(seconds)'
  exit 1
fi

ip=$1
iter=$2
urls=('yahoo.com' 'bing.com' 'google.com' 'facebook.com' 'instagram.com')
for x in $(seq 1 $iter); do
  rand_idx=$[RANDOM % 5]
  output=$(dig $ip ${urls[$rand_idx]})
  echo "$output"
  sleep 1
done 
