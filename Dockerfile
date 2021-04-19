FROM ubuntu:20.04

WORKDIR /root

COPY confs confs

COPY image-creator.sh image-creator.sh

COPY image-installer.sh image-installer.sh

RUN mkdir -p packages/tarballs

RUN mkdir hmi

COPY pds.zip hmi/pds.zip

WORKDIR /root/hmi

RUN unzip pds.zip

RUN mkdir opt

RUN mv qt opt/qt5-15-2

RUN mv pds_cutter opt/pds_cutter

RUN tar -czvf pds.tar.gz opt/

RUN mv pds.tar.gz ../packages/tarballs

WORKDIR /root

RUN bash image-creator.sh --arch amd64 --distro focal --image-type production --image-target installer

CMD cat production-image-installer_latest.bin
