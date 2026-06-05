#!/bin/bash
# https://claude.ai/share/256f15e2-cd71-409e-9270-7bef52dfbffa

cd ~/storage/downloads

echo "Starting rsync at $(date)"

time rsync --recursive \
--partial --append-verify \
--info=progress1 \
--verbose \
--stats --human-readable \
--bwlimit=42m \
`#backticks#--bwlimit=69m` \
synco/ root@192.168.0.42::synco

echo "Completed at $(date)"

sleep 69
echo -e '\a'

# Benchmark:
# sent 2.17G bytes  66.73M bytes/sec
# So speep without limit is 66m. You would need.less than 66m for a limit to have an effect.

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
