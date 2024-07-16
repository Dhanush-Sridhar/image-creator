# CLI options and examples

Default options are set in the config files:
- build.conf 
- image.conf

The examples section below gives you an idea hot to use the build scripts.

## Comandline options

Default: `./image-creator.sh --arch amd64 --distro focal --image-target installer --image-type production`

### Architecture

Set the rootfs architecture. The available architectures are **i386**, **amd64**, **armel** or **armhf**.
Default: amd64

`--arch <architecture-string>`

### Distro

- Set the rootfs distribution. 
- A list of available distributions can be found at /usr/share/debootstrap/scripts/. 
- Current Ubuntu LTS distribustions are xenial, bionix, focal, jammy, noble, ...

Default: focal
`--distro <distribution-string>`


### Image Target

Specify the image target. 

`--image-target <string>`

The following output targets are available:

#### loop:
- The loop target option creates an .img file with the image which can be installed on a (USB/harddisk) device via the dd commmand. 
- The size of the .img file is 16GB and contains a rootfs (8GB) partition and a datafs (8GB) partition.

#### /dev/sdX:
- The dev target option installs the image directly on the given device. 
- The device should have at least 9GB or more disk space. 
- The rootfs partition needs 8GB and the datafs partition will use the rest of the diskspace.

#### tarball:
- The tarball target option creates a rootfs tarball. 
- The tarball doesn't contain any partitions or fstab configuration. 
- The extracted tarball contents can be used as a chroot.

#### installer:
- The installer target option creates an executable .bin file which provides an installer to install the image. 
- In combination with a bootable Linux Live system the installer is the best option to install the image on new devices.



### Image Type

Specify the image type. 

`--image-type <string>`

The following image types are provided by the script:  

#### production
- The production image conatins the runtime dependencies and packages for the applications. 
- This image type should be used in combination with the installer target (see --image-target).

#### development
- The development image is meant to be used as a chroot to build the applications. 
- It has the development dependecies and packages installed. 
- The image has no X environment, but can also be installed on a device.

#### installation
- The installation image creates a minimal Live system which can be used in combination with the installer binary 
- installer needs to be copied in the installations image to install the image on a new device. 
- The image has no runtime dependecies or packages for the applications itself 
- but all needed functionality to install images from an external location.


### Clean
Clean the image-creator environment before creating images.
`--clean`

### Chroot
Start a chroot environment during the image creation to adjust the image contents manually.
`--enter-chroot`

### Install QT (deprecated)
Installs the Stephan Binner qt version 5.15.0 ...5.15.4 ubuntu package.
`--install-qt`

### Install Wi-Fi driver
Installs WIFI driver for USB WiFi/Bluetooth adapter:
- Clone RTL8188EU driver from github.com and copy `rtl8188eu-master` tar file into into image-creator dir `packages/drivers`
`--install-wifi`

## Examples

### Production image

Creates an Ubuntu focal (20.04) amd64 image file: rootfs-production.img
```sh
./image-creator.sh --arch amd64 --distro focal --image-target loop --image-type production
```

### Development chroot

Creates an Ubuntu focal (20.04) amd64 development chroot tarball: rootfs-development.tar.bz2
```sh
./image-creator.sh --arch amd64 --distro focal --image-target tarball --image-type development
```

### Installation (USB) image

First create the production image installer: production-image-installer_latest.bin
```sh
./image-creator.sh --arch amd64 --distro focal --image-target installer --image-type production
```

Then create a live system on USB at /dev/sdb
```sh
./image-creator.sh --arch amd64 --distro focal --image-target /dev/sdb --image-type installation
```




## Image-Installer

The image-installer script is used from the image-creator script to generate the image installer binary (see: image-creator.sh --image-target installer).
- Set the target device to install the image.
- The image will be installed on the given device.
- The device should have at least 9GB or more disk space.
- The rootfs partition needs 8GB and the datafs partition will use the rest of the diskspace.

`--image-target </dev/sdX>`
     
