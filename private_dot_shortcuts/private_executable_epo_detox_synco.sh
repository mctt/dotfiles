#!/bin/bash
cd ~/.shortcuts

me=$(basename "$0")

bash ~/.shortcuts/EPO.sh
bash ~/.shortcuts/detox.sh
bash ~/.shortcuts/Download_synco_to_pnas.sh

echo -e '\a' #beep
sleep 69
