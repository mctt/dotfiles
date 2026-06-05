termux-change-repo
#chage to europe mirror
pkg install coreutils
# installs sleep
# you can now sleep 1800 && ./rsync_pnas.sh
# waits 30mins the  runs command

pip install -U detoxpy

#pip install yt-dlp==2024.4.9.232723.dev0
#upgrade yt-dkp.back to latest version
pip install --upgrade yt-dlp
# or
#pip install -U yt-dlp
# https://github.com/yt-dlp/yt-dlp#impersonation
pip install "yt-dlp[default,curl-cffi]"
pkg install fastfetch

pkg install mc

pkg install cronie termux-services
sv-enable crond
crontab -e
#* * * * * mkdir ~/crontab-testing
#30 2 * * * ~/.shortcuts/all.sh
# so 30 2 means 2:30am every day
# minute 0-59
# hour 0-23
# dayofmonth 1-31
# monthofyear 1-12
# week 0-6

#https://github.com/spotDL/spotify-downloader
#spotDL can be installed by running 
pip install spotdl
#update
pip install -U spotdl yt-dlp

#or
#To update spotDL run
pip install --upgrade spotdl


#That “TooManyRedirects” is usually a redirect loop somewhere in spotDL’s chain (Spotify → search provider → lyrics provider → yt-dlp). A few quick fixes that normally clear it:

#1. Use a clean playlist URL (drop the tracking ?pi= bit)
#Temporarily disable AZLyrics as a lyrics source (there’s a fresh issue where AZLyrics can trigger a redirect loop)



#spotdl download https://open.spotify.com/playlist/6XtAUaryul3M5ncmdwdmMW --lyrics genius musixmatch --output ~/storage/download/synco/HYPE/

#(Recent GitHub issues mention TooManyRedirects tied to AZLyrics.)
