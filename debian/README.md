# Debian for Xiegu GSOC a.k.a puhuMod

The purpose of this script is to make Debian creating process a little more
automated. 

## 1. Prerequisites
* Linux host (no suprise here. I used Ubuntu 22.04)
* debootstrap and qemu-user-static
* ~2GB of free space

If debootstap and qemu-user-static are missing, please install them first:

```
sudo apt-get install debootstrap qemu-user-static binfmt-support
```

## 2. Build

The script should do the job. In theory no additional actions should be required. 
As a root simply run:

```
./make_puhu.sh /somepath
```

This automated process is responsible for: 

* creating base system
* adding extra repositories
* installing Xorg, OpenBox, HamClock, and required libraries
* creating posinstall and network scripts

## 3. Install and boot

For instructions how to prepeare storage for installing newly created Debian 
distro please refer to [USB](../usb_boot) or [SD](../sdcard_boot) section.
Once the storage is ready please copy all files created by this script 
to second (empty) partition. For example:

```
mount /dev/sdXXX2 /mnt/
cp -Rfa /somepath/* /mnt/
umount /mnt
```

Insert the SD card in the GSOC and boot
