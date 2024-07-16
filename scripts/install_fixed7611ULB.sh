#!/bin/bash

git clone https://github.com/lwfinger/rtl8723bu.git
cd rtl8723bu

#make
#sudo make install

sudo modprobe -v 8723bu

sudo touch -p /etc/modprobe.d/50-rtl8xxxu.conf   
blacklist rtl8xxxu >> /etc/modprobe.d/50-rtl8xxxu.conf


source dkms.conf
sudo mkdir /usr/src/$PACKAGE_NAME-$PACKAGE_VERSION
sudo cp -r core hal include os_dep platform dkms.conf Makefile rtl8723b_fw.bin /usr/src/$PACKAGE_NAME-$PACKAGE_VERSION
sudo dkms add $PACKAGE_NAME/$PACKAGE_VERSION
sudo dkms autoinstall $PACKAGE_NAME/$PACKAGE_VERSION

