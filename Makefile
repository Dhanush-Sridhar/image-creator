NAME=Polar-OS
VERSION=0.0.1

IMG=./image-creator.sh
LIVE=

pull: $(shell scripts/pull-packages.sh)

image:

livecd: scripts/liveos-creator.sh --all-img

clean:
	rm -f tmp/polar-live-os

all: $(PKG) $(SIG)

tag:
	git tag v$(VERSION)
	git push --tags

.PHONY: image livecd test tag clean
