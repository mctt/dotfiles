cd ~/storage/
rsync --recursive \
--progress \
--partial \
--append-verify \
--verbose \
--human-readable \
--bwlimit=24000 \
dcim/ root@192.168.0.16::Camera
sleep 5
