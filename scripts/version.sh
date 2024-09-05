#!/bin/bash

set -euo pipefail

help()
{
cat << EOM
Helper to print and update version string from Makefile

Usage:
  ./version.sh

Options:
  -h, --help        Show this help message.

  --show            Print the current version from the script.
  --update          Update the version number - Param: version number

Example:
    ./version.sh --show
    ./version.sh --update 1.2.3
    ./version.sh --update 1.2.3A
EOM
}

readonly REPO_ROOT=$(git rev-parse --show-toplevel)
readonly version_file=$REPO_ROOT/version
update_version=false
print_version=false
new_version=""


while [[ $# -gt 0 ]]; do
    argument="$1"

    case $argument in
        -h | --help)
            help
            exit 0
        ;;

        --show)
            print_version=true
            shift
        ;;

        --update)
            update_version=true
            if [ $# -gt 1 ]; then
                new_version="$2"
                shift 2
            else
                echo "Enter a version number! (Format: 1.2.3 or 1.2.3A)"
                exit 1
            fi
        ;;

        *)
            help
            break
        ;;
    esac
done

if [ "$(git rev-parse 2>/dev/null)" ]; then
  echo "WARNING: Not a git repo. No commit hash!"
fi


if $print_version; then
    version=$(grep -Eo '[0-9]\.[0-9]\.[0-9][A-Z]' $version_file || grep -Eo '[0-9]\.[0-9]\.[0-9]' $version_file)
    echo "$version"
fi

if $update_version; then

    echo "Your input: $new_version"

    current_version=$(grep -Eo '[0-9]\.[0-9]\.[0-9][A-Z]' $version_file || grep -Eo '[0-9]\.[0-9]\.[0-9]' $version_file)
    sed -i "s/$current_version/$new_version/g" $version_file

    git_hash=$(git rev-parse --short HEAD)
    new_version="${new_version} (${git_hash})      $(date +"%Y-%m-%d")"

    echo $new_version > $version_file
    echo "Version file was updated: $new_version"
fi
