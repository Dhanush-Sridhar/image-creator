#!/bin/bash

set -eo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
PKG_DIR=$REPO_ROOT/files/packages/deb

# TODO: maybe use S3 qt5-latest and nprodhd-update-latest
wget http://nexus-repository.polar-mohr-cloud.com:8081/repository/nprohd/pool/q/qt/qt_5-15-15_amd64.deb $PKG_DIR
wget http://nexus-repository.polar-mohr-cloud.com:8081/repository/nprohd/pool/n/nprohd-update/nprohd-update_2.3.0B_amd64.deb $PKG_DIR

# TODO: cli mit flags --nprohd --pure --nplus
