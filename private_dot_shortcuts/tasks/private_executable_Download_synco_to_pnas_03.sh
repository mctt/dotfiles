cd ~/storage/downloads

LOG=~/storage/downloads/rsync_$(date +%Y%m%d_%H%M%S).log
ITEMIZE="--itemize-changes"

echo "Starting rsync at $(date)" | tee $LOG

time rsync --recursive \
--partial \
--times \
--size-only \
--stats \
$ITEMIZE \
--verbose --human-readable \
--bwlimit=69m \
synco/ root@192.168.0.42::synco 2>&1 | tee -a $LOG

echo "Completed at $(date)" | tee -a $LOG

sleep 500
echo -e '\a'
