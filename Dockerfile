FROM ubuntu:20.04

WORKDIR /root

RUN apt update && apt install apt-utils -y
RUN apt update && apt upgrade -y && DEBIAN_FRONTEND=noninteractive apt install -y qemu-system-x86 expect libguestfs-tools

#RUN mkdir temp

#RUN debootstrap focal temp

#RUN echo "" > "temp/etc/apt/sources.list"

#RUN echo "deb http://de.archive.ubuntu.com/ubuntu focal main universe multiverse" >> temp/etc/apt/sources.list
#RUN echo "deb http://de.archive.ubuntu.com/ubuntu focal-updates main universe multiverse" >> temp/etc/apt/sources.list
#RUN echo "deb http://de.archive.ubuntu.com/ubuntu focal-security main universe multiverse" >> temp/etc/apt/sources.list
#RUN echo "deb http://de.archive.ubuntu.com/ubuntu focal-backports main universe multiverse" >> temp/etc/apt/sources.list

RUN qemu-img create -f qcow2 disk.qcow2 20G
#RUN wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.9.0-amd64-netinst.iso -nv -O debian.iso
RUN wget https://releases.ubuntu.com/focal/ubuntu-20.04.2.0-desktop-amd64.iso -nv -O ubuntu.iso
RUN wget -nv https://static-files.thepeaklab.cloud/vmlinuz
# qemu-system-x86_64 -cdrom debian.iso -hda disk.qcow2 -m 4G -smp $(nproc) -nographic -boot menu=on
# qemu-system-x86_64 -hda ubuntu.iso -kernel vmlinuz -append "root=/dev/sda2 console=ttyS0 3" -nographic

