#!/bin/bash

cd $(dirname $0) &&
mkdir -p ./backup &&
rsync -arvP -e "ssh  -o UserKnownHostsFile=./known_hosts" \
   --rsync-path="sudo /usr/bin/rsync" \
  --files-from=rsync-files-from.txt \
  pi@raspberrypi.local:/ ./backup/
