# Tiny Core Factory:
# https://tinycorefactory.github.io
#
# Architectures:
# x86_64
#
# Verified operating systems:
# dCorestretch64
#
# Description:
# Produces Bettercap extension, RAM disk, and ISO

# Make sure ISO exists
cd /tmp
if ! [ -e *.iso ]
	then
		echo 'The ISO to be used must be located in the /tmp directory!'
		exit
fi

# Get name of ISO
oldiso=$(find *.iso)

# Phase 1: Make extension

# Initialize workspace
mkdir -p /tmp/factory/new/var/bettercap/caplets
cd /tmp/factory
mkdir new/var/bettercap/ui
mkdir -p new/usr/local/share
mkdir new/usr/local/tce.installed
mkdir -p archives/bettercap
mkdir isoloop
mkdir newiso
mkdir -p release/extension
mkdir -p /var/bettercap

# Ensure tcedir does not point to an external device, as all imports and sces will be lost
rm /etc/sysconfig/tcedir
ln -s /tmp/tce /etc/sysconfig/tcedir

# Required Bettercap dependencies that must be included
echo 'libpcap0.8
libusb-1.0-0
libnetfilter-queue1
libnfnetlink0
libmnl0
iproute2'>dependencies

# Include additional driver support with ndiswrapper and other wireless extensions
#echo 'wireless
#wireless-4.14.10-tinycore64
#ndiswrapper
#ndiswrapper-modules-4.14.10-tinycore64'>>dependencies

# Import above dependencies
sce-import -ln dependencies

# Delete dependency import files no longer needed
rm -f dependencies
sudo rm -rf /tmp/tce/import/*

# Unsquash dependencies.sce
unsquashfs -f -d new -no-xattrs /tmp/tce/sce/dependencies.sce

# Delete dependency files no longer needed
sudo rm -rf /tmp/tce/sce/*

# Set bettercap archive name here
bczip=bettercap_linux_amd64_2.24.zip

# Download other packages to be included
wget https://github.com/bettercap/bettercap/releases/download/v2.24/$bczip -P archives
wget https://github.com/bettercap/caplets/archive/master.zip -P archives
wget https://github.com/bettercap/ui/releases/download/v1.3.0/ui.zip -P archives

# Inflate packages
unzip archives/$bczip -d archives/bettercap
unzip archives/master.zip -d archives
unzip archives/ui.zip -d archives

# Rename file names to prevent conflicts when combined
mv archives/bettercap/LICENSE.md archives/bettercap/bettercap-license.md
mv archives/bettercap/README.md archives/bettercap/bettercap-readme.md

# Import UPX, load, and clean up unneeded import files
sce-import -n upx-ucl
sudo rm -rf /tmp/tce/import/*
sce-load upx-ucl
sudo rm -rf /tmp/tce/sce/*

# Compress bettercap
upx-ucl --best --ultra-brute archives/bettercap/bettercap

# Copy packages to appropriate directories within new extension
sudo cp -a archives/bettercap/* new/usr/bin
sudo cp -a archives/caplets-master/* new/var/bettercap/caplets
sudo cp -a archives/ui/* new/var/bettercap/ui

# Delete archives
rm -rf archives

# Install script
echo 'ln -s /var/bettercap /usr/local/share'>new/usr/local/tce.installed/bettercap
chmod +x new/usr/local/tce.installed/bettercap

# Squash new extension directory into new sce file
mksquashfs new release/extension/betterbox.sce -b 4k -no-xattrs -all-root

# Hash new sce package
cd release/extension
md5sum betterbox.sce>betterbox.sce.md5.txt
cd ../..

# Phase 2: Make initrd

# Remove extension installation files not needed for initrd
sudo rm -rf new/usr/local/tce.installed
sudo rm -rf new/usr/local/sce
sudo rm -rf new/usr/local/postinst

# Create links
ln -s /var/bettercap new/usr/local/share
rm -rf /var/bettercap

# Mount ISO
mv ../$oldiso ./
sudo mount -o loop,ro $oldiso isoloop

# Copy ISO to newiso
sudo cp -a isoloop/boot newiso

# Unmount and delete old iso
sudo umount isoloop
rm -rf isoloop
rm -f $oldiso

# Get name of old initrd
cd newiso/boot
oldinitrd=$(find *.gz)
cd ../..

# Unpack initrd
cd new
zcat ../newiso/boot/$oldinitrd | sudo cpio -i -H newc -d

# Delete old initrd
sudo rm -f ../newiso/boot/$oldinitrd

# Reinforce permissions
sudo chown -R root:root *
sudo chmod -R 755 *

# Pack new initrd
sudo sh -c "find | cpio -o -H newc | gzip -2 > ../newiso/boot/BetterBox$oldinitrd"
cd ..

# Delete files no longer needed
sudo rm -rf new

# Import advancecomp, load, and clean up unneeded import files
sce-import -n advancecomp
sudo rm -rf /tmp/tce/import/*
sce-load advancecomp
sudo rm -rf /tmp/tce/sce/*

# Recompress initrd using advdef
sudo advdef -z4 newiso/boot/BetterBox$oldinitrd

# Copy initrd to release
cp newiso/boot/BetterBox$oldinitrd release

# Phase 3: Make ISO

# Reconfigure isolinux.cfg for new initrd
sudo sed -i "s+/boot/$oldinitrd+/boot/BetterBox$oldinitrd+g" newiso/boot/isolinux/isolinux.cfg

# Import genisoimage, load, and clean up unneeded import files
sce-import -n genisoimage
sudo rm -rf /tmp/tce/import/*
sce-load genisoimage
sudo rm -rf /tmp/tce/sce/*

# Build new ISO
sudo genisoimage -l -J -r -V BetterBox -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o release/BetterBox$oldiso newiso

# Delete unneeded ISO files
sudo rm -rf newiso
