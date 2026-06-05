termux-setup-tt-.sh has all the commands in it.

#Problem: Bitwarden bugs me for login with Auto-fill Popup mode.
Disable Autofill for Termux Only

1. Open the Bitwarden app on Android.

2. Go to Settings → Auto-fill.

3. Tap Auto-fill Services (or “Manage Auto-fill”).

4. Look for Excluded Apps / Blacklisted Apps (wording may vary by version).

5. Add 
androidapp://com.termux

crontab -e
https://www.reddit.com/r/termux/comments/i27szk/how_do_i_crontab_on_termux/

pkg cronie installed fine.. next command threw this mesage: sv-enable crond fail: crond: unable to change to service directory: file does not exist 

You have to restart termux.

