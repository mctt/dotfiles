
cd ~/storage/downloads

LOG=~/storage/downloads/rsync_$(date +%Y%m%d_%H%M%S).log
ITEMIZE=""

echo "Starting rsync at $(date)" | tee $LOG

time rsync --recursive \
`#--progress` --partial --append-verify \
--stats \
$ITEMIZE \
--times \
--size-only \
--`#itemize-changes` \
--verbose --human-readable \
--bwlimit=69m \
synco/ root@192.168.0.42::synco

echo "Completed at $(date)" | tee -a $LOG

sleep 500
echo -e '\a' #play beep

# --bwlimit=69m  means 69 MB/s.
# This 69m needs rsync 3.1.0+
#   10 Mbps =   1.25 MB/s ≈ --bwlimit=   1250
#   50 Mbps =   6.25 MB/s ≈ --bwlimit=   6250
#  100 Mbps =  12.5  MB/s ≈ --bwlimit= 1l2500
#    1 Gbps = 125.0  MB/s ≈ --bwlimit= 125000
#
# In the context of rsync --bwlimit=69m:
# 69m = 69 megabytes per second (MB/s)
# This is equivalent to:
# 69,000 KB/s (what you'd write as --bwlimit=69000 without the suffix)
# About 552 Mbps (69 × 8)

