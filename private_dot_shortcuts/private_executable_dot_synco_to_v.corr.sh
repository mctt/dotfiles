cd ~/storage/downloads
#remove -n to rename. n means dry run.
#detox -npr synco/*
detox -pr synco/*
rsync --recursive \
--stats \
--progress \
--partial \
--append-verify \
--verbose \
--human-readable \
#--bwlimit=24000 \
synco/ root@192.168.0.16::synco
#synco/ root@v.corruptive.co.uk::synco
