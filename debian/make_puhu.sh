#!/bin/bash

if [ -z "${1}" ]; then
    echo "Argument required. Please provide path for new Debian distro"
    echo "Usage: ${0} </absolute/path>"
    exit
fi

DESTPATH=${1}

if [ -d ${DESTPATH} ]; then
    echo "Folder already exists.Aborting"
    exit
fi


if [ ! -f /usr/bin/qemu-arm-static ]; then 
    echo "Missing qemu-arm-static. Please install."
    exit
fi

if [ ! -f /usr/sbin/debootstrap ]; then 
    echo "Missing debootstrap. Please install."
    exit
fi

if [ ! -f /usr/sbin/update-binfmts ]; then
    echo "Missing binfmt-support.  Please install."
    exit
fi


echo Bootstraping Debian
debootstrap --no-check-gpg --arch=armhf --include=ssh --foreign bookworm ${DESTPATH} ftp://ftp.ca.debian.org/debian

echo Copying the QEMU binary
cp /usr/bin/qemu-arm-static ${DESTPATH}/usr/bin

echo Chrooting and completing bootstrap
chroot ${DESTPATH} /debootstrap/debootstrap --second-stage

echo Updating Debian sources
echo "deb http://deb.debian.org/debian bookworm main contrib non-free-firmware" > ${DESTPATH}/etc/apt/sources.list
echo "deb http://deb.debian.org/debian bookworm-backports main contrib non-free-firmware" >> ${DESTPATH}/etc/apt/sources.list

echo Updating apt
chroot ${DESTPATH} apt update

echo Configuring system
echo "gsoc-puhu" > ${DESTPATH}/etc/hostname
echo "127.0.0.1 gsoc-puhu" >> ${DESTPATH}/etc/hosts

echo "/dev/root     /               ext4    errors=remount-ro 0       1" > ${DESTPATH}/etc/fstab

echo Configuring locale and installing dependencies
cat << EOF | chroot ${DESTPATH} /bin/bash
export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
apt-get -y install firmware-realtek wpasupplicant xorg openbox fspanel sudo locales curl make g++ libx11-dev libgpiod-dev network-manager nm-tray lightdm unzip
echo "en_US.UTF-8 UTF-8 >> /etc/locale.gen
locale-gen
EOF

echo Creating hamclock user
cat << EOF | chroot ${DESTPATH} /bin/bash
useradd -m -G sudo,tty,uucp -s /bin/bash hamclock
echo -en "hamclock\nhamclock\n" | passwd hamclock
EOF

echo Configuring X
if [ -f images/openbox.jpeg ]; then 
  mkdir ${DESTPATH}/usr/share/wallpapers
  cp images/openbox.jpeg ${DESTPATH}/usr/share/wallpapers
  echo "exec /usr/bin/openbox-session" > ${DESTPATH}/home/hamclock/.xinitrc
else 
  echo "exec /usr/bin/openbox-session" > ${DESTPATH}/home/hamclock/.xinitrc
fi

echo Configuring Autostart Applications
mkdir -p ${DESTPATH}/home/hamclock/.config/openbox

echo "
# Programs that will run after Openbox has started

# Set the wallpaper
hsetroot /usr/share/wallpapers/openbox.jpeg &

# Disable Screensaver
xset -dpms s off

# A panel for good times
fspanel &

#Launch wireless configuration on first boot
/home/hamclock/wireless-config.sh

#Launch HamClock
hamclock &
" > ${DESTPATH}/home/hamclock/.config/openbox/autostart

echo Creating network configuration
touch ${DESTPATH}/home/hamclock/firstboot

echo -e "#!/bin/bash
if [ -f /home/hamclock/firstboot ]; then
    xterm -e nmtui
    rm /home/hamclock/firstboot
    exit
fi
" > ${DESTPATH}/home/hamclock/wireless-config.sh

chmod +x ${DESTPATH}/home/hamclock/wireless-config.sh

echo Configuring HamClock
# Make HamClock launch in Full Screen
# This is a dirty hack and should be replaced by something nicer like xmlstarlet in the future
head -n -3 ${DESTPATH}/etc/xdg/openbox/rc.xml > ${DESTPATH}/etc/xdg/openbox/rc.xml.new
mv ${DESTPATH}/etc/xdg/openbox/rc.xml.new ${DESTPATH}/etc/xdg/openbox/rc.xml
echo '    <application title="HamClock">
        <maximized>yes</maximized>
    </application>
</applications>

</openbox_config>' >> ${DESTPATH}/etc/xdg/openbox/rc.xml

echo Configuring first-boot script
echo "#!/bin/bash
echo Mounting local GSOC storage
mount /dev/mmcblk1p2 /mnt/
echo Modules
cp -r /mnt/lib/modules /lib
rm /etc/rc.local
echo Modules installed.  Rebooting...
reboot

" > ${DESTPATH}/etc/rc.local

chmod +x ${DESTPATH}/etc/rc.local

cat << EOF | chroot ${DESTPATH} /bin/bash
systemctl enable rc-local.service
EOF

echo "Enabling auto-login"

echo "[SeatDefaults]
autologin-user=hamclock
autologin-user-timeout=0
user-session=openbox
" > ${DESTPATH}/etc/lightdm/lightdm.conf

echo "Setting root password"
cat << EOF | chroot ${DESTPATH} /bin/bash
echo -en "gsoc\ngsoc\n" | passwd root
EOF

echo "Building and installing hamclock binaries"
curl -o ${DESTPATH}/ESPHamClock.tgz https://www.clearskyinstitute.com/ham/HamClock/ESPHamClock.tgz
tar -xzf ${DESTPATH}/ESPHamClock.tgz -C ${DESTPATH}
cat << EOF | chroot ${DESTPATH} /bin/bash
cd /ESPHamClock
make -j 4 hamclock-800x480
make install
EOF

echo Updating Permissions
chown -Rf 1000:1000 ${DESTPATH}/home/hamclock

echo Cleaning Up
rm -Rf ${DESTPATH}/ESPHamClock
rm ${DESTPATH}/ESPHamClock.tgz

rm ${DESTPATH}/usr/bin/qemu-arm-static

echo Build complete
