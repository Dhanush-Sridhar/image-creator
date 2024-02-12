# README

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

Note: Sitemanager tarball uses a different path.

## Build

s. README.cmd.md


## Modification

### Add Installations
Sitemanger gets installed from a tarball with this snippet from `image-creator.sh`

```sh   
for TAR_FILE in $(ls -1 ${PKG_SITEMANAGER_PATH}/*.tar*)
do
    # ...
done
```



## Image-Installer

The image-installer script is used from the image-creator script to generate the image installer binary (see: image-creator.sh --image-target installer). 


## Known Bugs

WARNING:
If you forget a " for instance PKG="bla bla (no closing"), this installer can be executed and starts partioning your /dev/sda.


## TODO's

1. Install Qt5 option is deprecated because Stephan Binner (BasysKom) published only until Qt 5.15.4 on launchpad.net. We use Qt 5.15.15 or higher.
    - build it from source or take from pipeline (preferred) because takes a lot of time to build

2. Sitemanager (Remote Maintenance) was started by Sys-V init script with rc.local (Quick hack). Should be started with systemd service.
    - Note: Sitemanager tar is patched for polar usage.
    - Note: It is an old version. We should use a newer version. And add it as submodule
    - Repo: `git clone git@bitbucket.org:polar-cutting/sitemanagertar.git`
    - Autostart: /etc/init.d/sitemanager start

3. confs/app: .config / ISPV
    - polar not POLAR MOHR
    - maybe no initial config is better
    - cleanup: FCode, etc
    - ISPV_ROOT contains lot of cutting programms

4. openbox autostart
    - starts only /opt/pds-cutter/pds_cutter from PURE    