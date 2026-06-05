
cd ~/storage/downloads

rsync --recursive \
--progress --partial --append-verify \
--verbose --human-readable \
--bwlimit=12000 \
synco/ root@192.168.0.16::synco
sleep 5
