cd ~/storage/
rsync --recursive \
--progress \
--partial \
--append-verify \
--verbose \
--human-readable \
--bwlimit=24000 \
dcim/ root@192.168.0.42::Camera
#dcim/ root@v.corruptive.co.uk::Camera
sleep 5
