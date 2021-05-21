# Image-Creator

The image-creator script can build different variants of images for several output targets. These variants can be configured via the commandline options of the image-creator script.

## Comandline options

- `--arch <architecture-string>`
Set the rootfs architecture. The available architectures are **i386**, **amd64**, **armel** or **armhf**.
**Default:** amd64

- `--distro <distribution-string>`
Set the rootfs distribution. A list of available distributions can be found at /usr/share/debootstrap/scripts/. Current Ubuntu LTS distribustions are xenial, bionix or focal.
**Default:** focal

- `--image-target <string>`
  Specifiy the image target. The following output targets are available:
  - **loop:**
  The loop target option creates an .img file with the image which can be installed on a (USB/harddisk) device via the dd commmand. The size of the .img file is 16GB and contains a rootfs (8GB) partition and a datafs (8GB) partition.
  - **/dev/sdX:**
  The dev target option installs the image directly on the given device. The device should have at least 9GB or more disk space. The rootfs partition needs 8GB and the datafs partition will use the rest of the diskspace.
  - **tarball:**
  The tarball target option creates a rootfs tarball. The tarball doesn't contain any partitions or fstab configuration. The extracted tarball contents can be used as a chroot.
  - **installer:**
  The installer target option creates a executable .bin file which provides an installer to install the image. In combination with a bootable Linux Live system the installer is the best option to install the image on new devices.
  
- `--image-type <string>`
  Specifiy the image type. The following image types are provided by the script:
  - **production**
    The production image conatins the runtime dependencies and packages for the applications. This image type should be used in combination with the installer target (see --image-target).
  - **development**
    The development image is meant to be used as a chroot to build the applications. It has the development dependecies and packages installed. The image has no X environment, but can also be installed on a device.
  - **installation**
    The installation image creates a minimal Live system which can be used in combination with the installer binary (installer needs to be copied in the installations image) to install the image on a new device. The image has no runtime dependecies or packages for the applications itself but all needed functionality to install images from an external location.

- `--install-qt`
Installs the Stephan Binner qt version 5.15.0 ubuntu package.

- `--clean`
Clean the image-creator environment before creating images.

- `--enter-chroot`
Start a chroot environment during the image creation to adjust the image contents manually.

## Examples

### Production image
Creates an Ubuntu focal (20.04) amd64 image file
```
$> ./image-creator.sh --arch amd64 --distro focal --image-target loop --image-type production
--> rootfs-production.img
```

### Development chroot
Creates an Ubuntu focal (20.04) amd64 development chroot tarball:
```
$> ./image-creator.sh --arch amd64 --distro focal --image-target tarball --image-type development
--> rootfs-development.tar.bz2
```

### Installation (USB) image
Creates an Ubuntu focal (20.04) amd64 production image installer (needed for the Installation image)
```
$> ./image-creator.sh --arch amd64 --distro focal --image-target installer --image-type production
--> production-image-installer_latest.bin
```

Creates an Ubuntu focal (20.04) amd64 live system on an USB device at /dev/sdb
```
$> ./image-creator.sh --arch amd64 --distro focal --image-target /dev/sdb --image-type installation
--> /dev/sdb
```



## Peaklab-Version

Build the application locally on a linux machine (without Jenkins-Server).

- **Step 1:** Execute the following commands in the `pm_pcm_cutter_v3` repository to create a debian-package of the application

```sh
# Notice: at first time this command may take several minutes to hours depending on your system
docker build -f Dockerfile.peaklab -t temp .

docker run --rm temp > pds_cutter.deb
```

- **Step 2:** Copy the output into the image-creator directory 

   `/image-creator/packages/deb/pds_cutter.deb`

- **Step 3:** Run the the image-creator script on branch peaklab-version

  <span style="color:red;font-weight:bold">TODO: verify correct procedure with Mathis</span>

# Image-Installer

The image-installer script is used from the image-creator script to generate the image installer binary (see: image-creator.sh --image-target installer). 

## Comandline options

- `--image-target </dev/sdX>`
Set the target device to install the image. The image will be installed on the given device. The device should have at least 9GB or more disk space. The rootfs partition needs 8GB and the datafs partition will use the rest of the diskspace.