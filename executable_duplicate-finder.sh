#/bin/bash
# https://unix.stackexchange.com/questions/277697/whats-the-quickest-way-to-find-duplicated-files
# or just use fdupes -r storage/downloads/
# fdupes -rdN
# -r recursive
# -d delete
# -N no interaction. Silent delete.
find . ! -empty -type f -exec md5sum {} + | sort | uniq -w32 -dD
