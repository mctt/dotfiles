
cd ~/.shortcuts
me=$(basename "$0")

./EPO.sh
./detox.sh
./Download_synco_to_pnas.sh

echo -e '\a' #beep
sleep 69

