#!/bin/bash

# Configure Linux Mint 22.1 for public use
# - Sets up guest session access
# - Hides things that users shouldn't need
#
# How to apply:
# - Install Linux Mint 22.1
# - Access with existing user with sudo access and open a terminal
# - $sudo su
# - $curl -L https://panreyes.com/lm_kiosk | bash

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

mkdir -p /etc/guest-session/skel/.config/autostart
mkdir -p /etc/guest-session/skel/.local/share/applications

# For updating Firefox to latest version
install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "\nThe key fingerprint matches ("$0").\n"; else print "\nVerification failed: the fingerprint ("$0") does not match the expected one.\n"}'

cat <<EOF > /etc/apt/sources.list.d/mozilla.sources
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF

echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | tee /etc/apt/preferences.d/mozilla

# Activate guest session
printf "[Seat:*]\nallow-guest=true\n" | tee /etc/lightdm/lightdm.conf

# Remove unneeded software
apt -y remove --purge hexchat transmission-* thunderbird rhythmbox hypnotix warpinator celluloid pix

# Install Firefox and Chromium
apt-get -y update && apt-get -y install firefox chromium

# Disable autostart from these applications
cp /etc/xdg/autostart/{blueman.desktop,mintreport.desktop,nvidia-prime.desktop,xapp-sn-watcher.desktop,gnome-keyring-ssh.desktop,mintupdate.desktop} /etc/guest-session/skel/.config/autostart

for f in /etc/guest-session/skel/.config/autostart/{blueman.desktop,mintreport.desktop,nvidia-prime.desktop,xapp-sn-watcher.desktop,gnome-keyring-ssh.desktop,mintupdate.desktop}; do
    echo "X-GNOME-Autostart-enabled=false" >> "$f"
done

# Configure enabled applets
tee /etc/guest-session/skel/.xprofile >/dev/null <<'EOF'
#!/bin/bash
gsettings set org.cinnamon enabled-applets "['panel1:left:1:separator@cinnamon.org:1', 'panel1:left:2:grouped-window-list@cinnamon.org:2', 'panel1:right:1:systray@cinnamon.org:3', 'panel1:right:2:xapp-status@cinnamon.org:4', 'panel1:right:4:printers@cinnamon.org:6', 'panel1:right:5:removable-drives@cinnamon.org:7', 'panel1:right:9:sound@cinnamon.org:11', 'panel1:right:11:calendar@cinnamon.org:13', 'panel1:right:12:cornerbar@cinnamon.org:14', 'panel1:right:0:user@cinnamon.org:15']"
EOF

# Configure Firefox to launch in private mode
cp /usr/share/applications/firefox.desktop /etc/guest-session/skel/.local/share/applications/
sed -i 's/^Exec=firefox/Exec=firefox -private/' /etc/guest-session/skel/.local/share/applications/firefox.desktop

# Configure Chromium to run in incognito mode
cp /usr/share/applications/chromium-browser.desktop /etc/guest-session/skel/.local/share/applications/
sed -i 's/^Exec=chromium/Exec=chromium --temp-profile --incognito --disable-features=PasswordManager --password-store=basic/' /etc/guest-session/skel/.local/share/applications/chromium-browser.desktop
sed -i 's/^Terminal=false/Terminal=true/' /etc/guest-session/skel/.local/share/applications/chromium-browser.desktop

# Hide Terminal and show Chromium in pinned apps
sed -i 's/org.gnome.Terminal.desktop/chromium-browser.desktop/' /usr/share/cinnamon/applets/grouped-window-list\@cinnamon.org/settings-schema.json

echo "Process complete!"
