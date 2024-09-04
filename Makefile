.PHONY: pull installer live-os clean show-version  tag all

VERSION = $(shell cat version)

#Pulls debian packages from Nexus apt repo or S3 (quick and dirty yet)
pull:
	./scripts/pull-packages.sh

installer:
	./scripts/image-creator.sh

live-os:
	./scripts/liveos-creator.sh --all-img

clean:
	./scripts/cleanup.sh

tag:
	git tag v$(VERSION)
	git push --tags

show-version:
	@echo $(VERSION)

# show help
help:
	@echo "======================================================================"
	@echo "                   Polar OS Image Creator v1.0"
	@echo "======================================================================"
	@echo "  Creator: 	Dhanush Sridhar, Suria Redddy"
	@echo "  Date:		09/2024"
	@echo
	@echo " USAGE: make [OPTION]"
	@echo
	@echo " OPTIONS:"
	@echo "  all         		Execute all scripts to build an installer and live system."
	@echo "  pull	     		Pull debian packages from Nexus/S3"
	@echo "  installer		    Build the Polar OS rootfs and the binary installer."
	@echo "  live-os      		Build the Live System as .img file."
	@echo "  clean      		Call cleanup script (not implemented yet)."
	@echo
	@echo "  help        		Show this help"
	@echo "======================================================================"
