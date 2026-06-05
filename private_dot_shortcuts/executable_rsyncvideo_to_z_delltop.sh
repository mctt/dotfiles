#!/bin/bash
# rsyncvideo_to_z_delltop.sh
# https://claude.ai/share/4f491f57-f7b6-41cf-a3f0-93caaa677f09
ssh -i ~/storage/downloads/id_rsa -p 2218 user@v.corruptive.co.uk \
  './rsyncvideo_to_z.sh'

sleep 5
echo -e '\a' # play beep
