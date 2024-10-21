# Polar OS Image Creator

## Overview

The Polar OS Image Creator is a tool designed to create custom Debian-based images using debootstrap. These images are packaged into a live system that serves as an installation medium for Box-PC applications. The project supports multiple machine types and configurations, allowing for flexible and efficient image creation and deployment.

## Features

- **Custom Image Creation**: Build Debian-based images tailored to specific machine types using debootstrap.
- **Live System Packaging**: Package images into a live system for easy installation on Box-PCs.
- **Support for Multiple Architectures**: Create images for various architectures, including i386, amd64, armel, and armhf.
- **Automated Installation**: Use the live system as an installation medium with automated scripts for seamless deployment.

## Prerequisites

- A Linux-based system with `bash` and essential build tools installed.
- Access to a Debian or Ubuntu repository for debootstrap.
- Git for cloning the repository and managing versions.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone git@bitbucket.org:polar-cutting/image-creator.git
   cd image-creator
   ```

2. **Install Dependencies**:
   Run the following command to install necessary packages:
   ```bash
   sudo apt update
   sudo apt install debootstrap grub-pc-bin make 
   ```

3. **Configure the Environment**:
   Edit the configuration files located in `scripts/config/` to set up your build environment. Key files include:
   - `build.conf`: General build settings. Refere to `docs/build.Conf_variables.md` for details 
   - `nplus-image.conf`, `npro-image.conf`, `pure-image.conf`: Machine-specific configurations. Refere to `docs/image.conf_variables.md` for details

## Usage

### Building an Image

To create a custom image and package it into a live system, use the `Makefile` to streamline the process. The `Makefile` provides several targets to automate tasks such as pulling packages, building the installer, and creating a live system. To build an image and package it into a live system, use the following command:

```bash
sudo make all
```

This command will execute all necessary scripts to build the installer and live system, as defined in the `Makefile`. It will:

- Pull Debian packages from the Nexus or S3 repository.
- Build the Polar OS root filesystem and the binary installer.
- Create the live system as an image file.

### Output Artifacts

The output artifacts, including the final image files, are located in the `tmp` folder within the repository. The final image file, typically with a `.img` extension, can be flashed to a USB drive using tools like Rufus or Raspberry Pi Imager.

### Flashing the Image

To flash the image onto a USB drive, use a tool like Rufus or Raspberry Pi Imager. This will allow you to use the USB drive as a bootable installation medium for the Box-PC.

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes. Ensure that your code adheres to the project's coding standards and includes appropriate documentation.

## Contact

For questions or support, please contact the project maintainers:

- Dhanush Sridhar
- Suria Reddy