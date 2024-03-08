#!/bin/sh

##################################################################
# This script gathers files with uncommited changes and invokes the 
# SwiftLint tool only on the changed files.
#
# Features:
#  - If the `AUTO_FIX` is set to `true` (default) the tool will fix
#    any violation that can be automatically fixed by the underlaying tool.
#  - Exits (with `exit 0`) when the script is invoked from Xcode
#    Previews. When the preview refreshes, it invokes all build
#    phases.
#  - Exits (with `exit 0`) when the script is invoked from 
#    CI pipeline
#
# See LICENSE for more details.
##################################################################

# We only want this script to run locally
# and not when running via CI/CD pipeline
if [ $CI ]; then
  echo "The CI variable was set; therefore this script won't run."
  exit 0
fi

# We want to prevent this script from running
# when it is invoked from during the Xcode Previews build.
case "$BUILD_DIR" in
	*Previews*) echo "** Running in Xcode Previews; linter will not run." && exit 0 ;;
	*) echo "** Running outside of previews" ;;
esac

# Adding Homebrew to the PATH for Apple Silicon
# This is only needed for Homebrew; because Xcode
# does not add these to the PATH when running a
# script as part of the build phase.
if [[ `uname -m` == 'arm64' ]]; then
  echo "** Running on Apple Silicon"
  PATH=${PATH}:/opt/homebrew/bin:/opt/homebrew/sbin
else
  echo "** Running on a Apple x86"
fi

# CONFIGURATION
# set swiftformat path or executable
SWIFTLINT="$(which swiftlint)"

# set swiftformat config location
CONFIG="$(cd "$(dirname "$0")/.."; pwd)/.swiftlint"

echo "Looking for config in: $CONFIG"

# file types to parse. Only effective when PARSE_EXTS is true.
# FILE_EXTS=".c .h .cpp .hpp"
FILE_EXTS=".swift"

# Automatically fix violations that can be fixed
AUTO_FIX=true

. "$(dirname -- "$0")/canonicalize_filename.sh"

# exit on error
set -e

# make sure the config file and executable are correctly set
if [ ! -f "$CONFIG" ] ; then
    printf "Error: swiftlint config file not found.\n"
    printf "Set the correct path in $(canonicalize_filename "$0").\n"
    exit 0
fi

if ! command -v "$SWIFTLINT" > /dev/null ; then
    printf "Error: swiftlint executable not found.\n"
    printf "Set the correct path in $(canonicalize_filename "$0")\n"
    printf "or download from https://github.com/realm/SwiftLint"
    exit 0
fi

# check whether the given file matches any of the set extensions
matches_extension() {
    local filename="$(basename -- "$1")"
    local extension=".${filename##*.}"
    local ext

    for ext in $FILE_EXTS; do [ "$ext" = "$extension" ] && return 0; done

    return 1
}

# Get a list of modified files from Git (including files with spaces)

MODIFIED_FILES=$(git diff --diff-filter=AM --name-only HEAD)

# Loop through the list and quote each file path
quoted_files=()
while IFS= read -r -d $'\n' file; do
  if ! matches_extension "$file"; then
	  continue;
  fi
  quoted_files+=("$file")
done <<< "$MODIFIED_FILES"

if [ ${#quoted_files[@]} -gt 0 ]; then
	# Pass the list of files to SwiftLint for processing
  if [ $AUTO_APPLY ] ; then
  	"$SWIFTLINT" lint --fix --config "$CONFIG" "${quoted_files[@]}"
  fi
  
	"$SWIFTLINT" lint --config "$CONFIG" "${quoted_files[@]}"
else
	echo "No changes to source code were detected."
fi
