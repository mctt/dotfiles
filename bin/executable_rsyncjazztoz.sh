#/!/bin/bash

cd /mnt/unas/

rsync --recursive \
--progress --partial --append-verify \
--verbose --human-readable \
--bwlimit=69m \
s/Jazz/ user@192.168.0.18:/cygdrive/z/s/Jazz/

# fill in directory below
# delltop
#-e "ssh -i /root/.ssh/id_rsa" \

# unas
#fix/TopLine 
#s/Jazz/ root@192.168.0.42:/mn

# qnas
#fix/TopLine root@192.168.0.16:/mnt/unas/_crap/

#sleep 5
#echo -e '\a' #play beep

# --bwlimit=69m  means 69 MB/s.
# This 69m needs rsync 3.1.0+
#   10 Mbps =   1.25 MB/s ≈ --bwlimit=   1250
#   50 Mbps =   6.25 MB/s ≈ --bwlimit=   6250
#  100 Mbps =  12.5  MB/s ≈ --bwlimit=  12500
#    1 Gbps = 125.0  MB/s ≈ --bwlimit=125000

