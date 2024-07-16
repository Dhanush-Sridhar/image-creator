# README

This repo contains config files and shell scripts to create a binary installer with debootstrap. 
It's also possible to create images for non-desktop target platforms. 

## Quickstart

1. Add your packages into files/packages/{binaries,deb,tarballs} i.e. HMI application, Qt-Libs
2. Edit the build.conf and image.conf (optional)
3. Build your target (production installer in most cases) - s. README.cmd.md


## Build

s. README.cmd.md

Examples:
Binary Installer:   `./image-creator.sh --arch amd64 --distro focal --image-target installer --image-type production`
Live System on USB: `./image-creator.sh --arch amd64 --distro focal --image-target /dev/sdb --image-type installation`


## How it works

Shell scripts to build a Linux image with debootstrap and configure it via chroot commands. 

## Structure

This repos contains all config files inside `confs`:
- `app` - ISPV_root and initial .config (from QSettings) 
- `system` - Linux system dirs like `etc` and `var`

## Configure

First feed the `packages` dir with packages to install.

Formats: tarball, debian (.deb), binaries

Paths:
- packages/deb
- packages/tarballs
- packages/binaries


