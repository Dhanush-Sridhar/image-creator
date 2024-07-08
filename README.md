# Image-Creator

This repo contains config files and shell scripts to create a binary installer with debootstrap. 
It's also possible to create images for non-desktop target platforms. 

## Build

1. Add your packages into files/packages/{binaries,deb,tarballs} i.e. HMI application, Qt-Libs
2. Edit the build.conf and image.conf (optional)
3. Build your target (production installer in most cases) - s. README.cmd.md

**Examples**
Binary Installer:   `./image-creator.sh --arch amd64 --distro focal --image-target installer --image-type production`
Live System on USB: `./image-creator.sh --arch amd64 --distro focal --image-target /dev/sdb --image-type installation`

## How it works


