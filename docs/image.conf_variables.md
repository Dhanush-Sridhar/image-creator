# xx-image.conf Variables Explained

This document explains the variables used in the `nplus-image.conf` file, which configures the image creation process for the nplus platform.
similar config files exits to build images for for npro and pure machine types


## Debootstrap Settings

*   **`APT_CMD`**: The command used to invoke the APT package manager.  Defaults to `apt`.
*   **`ARCH`**: The target architecture for the rootfs. Defaults to `amd64`.
*   **`DISTRO`**: The target Debian/Ubuntu distribution for the rootfs (e.g., `focal`, `jammy`, `noble`). Defaults to `noble`.
*   **`DEBOOTSTRAP_OPTIONS`**: Additional options passed to the `debootstrap` command. Defaults to `--variant=minbase http://archive.ubuntu.com/ubuntu`.
*   **`GIT_COMMIT`**:  Captures the short Git commit hash during build time.  Used for versioning.

## Image Configurations

*   **`VERSION`**: The version string for the image. Includes the Git commit hash.
*   **`IMAGE_USER`**: The default username for the image. Defaults to `polar`.
*   **`IMAGE_PASSWORD`**: The default password for the `IMAGE_USER`. Defaults to `Tomate+4`.
*   **`IMAGE_HOSTNAME`**: The hostname set for the image. Defaults to `nplus-sbc`.
*   **`VNC_PASSWORD`**:  The password used for VNC access. Defaults to the same value as `IMAGE_PASSWORD`.

## Package Lists

*   **`KERNEL_PKG`**: Specifies the kernel package to install. Defaults to `--install-recommends linux-generic`.
*   **`PKG_BASE_IMAGE`**:  Essential packages installed in the base image. Includes `sudo`, `apt-utils`, locale settings, and console setup tools.
*   **`PKG_RUNTIME_IMAGE`**: Packages required for the runtime environment. Includes networking tools, utilities, X11 components, VNC server, and multimedia libraries.
*   **`PKG_INSTALLATION_IMAGE`**: Packages needed for the installation process. Includes `gdisk` for partitioning.
*   **`PKG_LIVEOS`**: Packages specifically for live OS environments. Includes `bzip2` for compression.

## Additional Package Settings

*   **`INSTALL_QT5`**: Flag to indicate whether to install Qt5. Defaults to `NO`.
*   **`INSTALL_WIFI`**: Flag to indicate whether to install Wi-Fi drivers. Defaults to `YES`.
*   **`INSTALL_SITE_MANAGER`**: Flag to indicate whether to install the Site Manager. Defaults to `YES`.
*   **`PULL_PACKAGES`**: Flag to control pulling packages from an external repository (e.g. Nexus). Defaults to `NO`.

## Nexus Repository Settings

*   **`INSTALL_NEXUS_PKG`**: Flag to enable installation of packages from a Nexus repository. Defaults to `YES`.
*   **`NEXUS_REPO_KEYRING`**: URL of the Nexus repository's keyring file for authentication.
*   **`KEYRING_PATH`**: Path where the downloaded keyring file will be stored on the target system.
*   **`NEXUS_APT_URL`**: URL of the Nexus APT repository.
*   **`NEXUS_PACKAGES`**: List of packages to install from the Nexus repository.  Defaults to `tms34010-sim sbc-pnet-port-forwarding`.

## Development Packages (Not for Production)

*   **`PKG_DEV_IMAGE`**: Packages required for a development environment. Includes build tools, debugging tools, and network analysis tools.  Not intended for production images.

## Additional Image Settings

*   **`INSTALL_APP_DATA`**: Flag to enable installation of application data. Defaults to `NO`.

## Debootstrap Settings

*   **`APT_CMD`**: The command used to invoke the APT package manager.  Defaults to `apt`.
*   **`ARCH`**: The target architecture for the rootfs. Defaults to `amd64`.
*   **`DISTRO`**: The target Debian/Ubuntu distribution for the rootfs (e.g., `focal`, `jammy`, `noble`). Defaults to `noble`.
*   **`DEBOOTSTRAP_OPTIONS`**: Additional options passed to the `debootstrap` command. Defaults to `--variant=minbase http://archive.ubuntu.com/ubuntu`.
*   **`GIT_COMMIT`**:  Captures the short Git commit hash during build time.  Used for versioning.

## Image Configurations

*   **`VERSION`**: The version string for the image. Includes the Git commit hash.
*   **`IMAGE_USER`**: The default username for the image. Defaults to `polar`.
*   **`IMAGE_PASSWORD`**: The default password for the `IMAGE_USER`. Defaults to `Tomate+4`.
*   **`IMAGE_HOSTNAME`**: The hostname set for the image. Defaults to `nplus-sbc`.
*   **`VNC_PASSWORD`**:  The password used for VNC access. Defaults to the same value as `IMAGE_PASSWORD`.

## Package Lists

*   **`KERNEL_PKG`**: Specifies the kernel package to install. Defaults to `--install-recommends linux-generic`.
*   **`PKG_BASE_IMAGE`**:  Essential packages installed in the base image. Includes `sudo`, `apt-utils`, locale settings, and console setup tools.
*   **`PKG_RUNTIME_IMAGE`**: Packages required for the runtime environment. Includes networking tools, utilities, X11 components, VNC server, and multimedia libraries.
*   **`PKG_INSTALLATION_IMAGE`**: Packages needed for the installation process. Includes `gdisk` for partitioning.
*   **`PKG_LIVEOS`**: Packages specifically for live OS environments. Includes `bzip2` for compression.

## Additional Package Settings

*   **`INSTALL_QT5`**: Flag to indicate whether to install Qt5. Defaults to `NO`.
*   **`INSTALL_WIFI`**: Flag to indicate whether to install Wi-Fi drivers. Defaults to `YES`.
*   **`INSTALL_SITE_MANAGER`**: Flag to indicate whether to install the Site Manager. Defaults to `YES`.
*   **`PULL_PACKAGES`**: Flag to control pulling packages from an external repository (e.g. Nexus). Defaults to `NO`.

## Nexus Repository Settings

*   **`INSTALL_NEXUS_PKG`**: Flag to enable installation of packages from a Nexus repository. Defaults to `YES`.
*   **`NEXUS_REPO_KEYRING`**: URL of the Nexus repository's keyring file for authentication.
*   **`KEYRING_PATH`**: Path where the downloaded keyring file will be stored on the target system.
*   **`NEXUS_APT_URL`**: URL of the Nexus APT repository.
*   **`NEXUS_PACKAGES`**: List of packages to install from the Nexus repository.  Defaults to `tms34010-sim sbc-pnet-port-forwarding`.

## Development Packages (Not for Production)

*   **`PKG_DEV_IMAGE`**: Packages required for a development environment. Includes build tools, debugging tools, and network analysis tools.  Not intended for production images.

## Additional Image Settings

*   **`INSTALL_APP_DATA`**: Flag to enable installation of application data. Defaults to `NO`.