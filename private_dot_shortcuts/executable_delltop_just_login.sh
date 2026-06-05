# https://claude.ai/share/7e17934f-a53b-4f4b-9b13-e32a05f5ffbe
#works fine# ssh -i ~/storage/downloads/id_rsa -p 2218 user@v.corruptive.co.uk "screen -dmS rsyncx ./rsyncxxx_to_pnas.sh"

#1
#rmcrap.sh
ssh -i ~/storage/downloads/id_rsa -p 2218 user@v.corruptive.co.uk "screen -dmS rmrf bash -c './rmcrap.sh ; killall -9 rsync ; exit'"

#2
#rsyncxxx_to_pnas.sh
ssh -i ~/storage/downloads/id_rsa -p 2218 user@v.corruptive.co.uk "screen -dmS rsyncx bash -c './rsyncxxx_to_pnas.sh ; exit'" && sleep 2 && ssh -i ~/storage/downloads/id_rsa -p 2218 user@v.corruptive.co.uk "tail -f rsync.log 2>/dev/null || (sleep 3 && tail -f rsync.log)"

#3
#rsync.log # separated out for clarity.
#sleep 2 #no need for extra sleep
##ssh -i ~/storage/downloads/id_rsa -p 2218 user@v.corruptive.co.uk "tail -f rsync.log 2>/dev/null || (sleep 3 && tail -f rsync.log)"

sleep 5
echo -e '\a' #play beep
