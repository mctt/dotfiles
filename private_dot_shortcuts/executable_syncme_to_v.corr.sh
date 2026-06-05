cd ~/storage/shared
rsync --recursive \
-vv \
--progress \
--partial \
--append-verify \
--verbose \
--human-readable \
--bwlimit=24000 \
syncme/ root@v.corruptive.co.uk::syncme
sleep 5
