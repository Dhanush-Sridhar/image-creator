#!/bin/bash

set -eo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
PKG_DIR=$REPO_ROOT/files/packages/deb

# TODO: maybe use S3 qt5-latest and sitemanager 
wget http://nexus-repository.polar-mohr-cloud.com:8081/repository/nprohd/pool/q/qt/qt_5-15-15_amd64.deb -P $PKG_DIR
wget http://nexus-repository.polar-mohr-cloud.com:8081/repository/nprohd/pool/s/sitemanager/sitemanager_1.0.0_amd64.deb -P $PKG_DIR

# TODO: cli mit flags --nprohd --pure --nplus
