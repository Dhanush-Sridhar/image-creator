# `build.conf` Variable Descriptions

This document details the variables within the `build.conf` file, crucial for configuring the Polar OS image build process.

## Work/Script Path Variables

*   **`REPO_ROOT`**: Absolute path to the root of the git repository, derived using `git rev-parse --show-toplevel`.  Serves as a base for other paths.
*   **`TMP_PATH`**: Path to the temporary directory within the repository (`REPO_ROOT/tmp`).  Stores intermediate build artifacts.

## Machine Type Variable

*   **`MACHINE`**:  Specifies the target machine type for the image (e.g., `nplus`, `nprohd`, `pure`).  Influences configuration selection.  Defaults to `nplus`.

## Build Options Variables

*   **`IMAGE_TYPE`**:  Defines the image type being built (e.g., `production`, `development`, `installation`).  Determines included packages and configurations. Defaults to `production`.
*   **`IMAGE_TARGET`**: Specifies the output format of the image (e.g., `installer`, `loop`, `tarball`). Defaults to `installer`.
*   **`BUILD_DATE`**:  The date of the build in YYYY-MM-DD format. Used for versioning and tracking.

## File Path Variables

*   **`INSTALLER_SCRIPT`**: Path to the `image-installer.sh` script, responsible for creating the installer binary.
*   **`ROOTFS_IMAGE_FILE`**: Path to the root filesystem image file (`rootfs.img`). Used for loopback devices.
*   **`ROOTFS_TARBALL`**: Path to the compressed root filesystem tarball (`rootfs.tar.bz2`).
*   **`ROOTFS_PATH`**: Path to the root filesystem directory (`tmp/rootfs`).  Used as a mount point during build.
*   **`ROOTFS_BASE_CACHE_PATH`**: Path to the rootfs cache directory, specific to the machine type.  Used to speed up rebuilds.
*   **`LIVE_SYSTEM_CACHE_PATH`**: Path to the live system cache directory.  Used to speed up live system creation.
*   **`DATAFS_PATH`**: Path to the data partition within the root filesystem (`tmp/rootfs/data`).
*   **`INSTALLER_BINARY`**: Path to the final installer binary file, named according to machine, image type, and date.
*   **`INSTALLER_SYMLINK`**: Path to a symbolic link pointing to the latest installer binary, simplifying access.

## Configuration Path Variables

*   **`ROOTFS_CONF_PATH`**: Path to the directory containing system configuration files copied into the rootfs.
*   **`APP_CONF_PATH`**: Path to the directory containing application-specific configuration files.
*   **`PERMISSIONS_CONF`**: Path to the file defining file permissions and ownership within the rootfs.

## Package Path Variables

*   **`PKG_PATH`**: Base path for package files.
*   **`PKG_DEB_PATH`**: Path to the directory containing `.deb` package files.
*   **`PKG_TARBALLS_PATH`**: Path to the directory containing tarball packages.
*   **`PKG_BINARIES_PATH`**: Path to the directory containing binary files.
*   **`PKG_DRIVER_PATH`**: Path to the directory containing driver packages.

## Build Option Flags

*   **`CLEAN`**: Flag to clean the build environment.  Defaults to `NO`.
*   **`ENTER_CHROOT`**: Flag to enter a chroot environment after image creation. Defaults to `NO`.

## Option Lists

*   **`ARCH_LIST`**: Space-separated list of supported architectures.
*   **`IMAGE_TYPE_LIST`**: Space-separated list of supported image types.
*   **`MACHINE_LIST`**: Space-separated list of supported machine types.

## Repository URLs

*   **`REPO_URL_ARM`**: URL for the ARM architecture package repository.
*   **`REPO_URL_X86`**: URL for the x86 architecture package repository.
*   **`REPO_COMPONENTS`**: Space-separated list of repository components (e.g., `main universe multiverse`).