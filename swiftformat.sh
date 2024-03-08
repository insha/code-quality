#!/bin/sh

##################################################################
# This script gathers uncommited changes and invokes the 
# SwiftFormat tool only on those changes.
#
# Features:
#  - Exits when changes do not comply with the style guidelines
#  - Creates a patch of the proposed style changes
#  - If the `AUTO_APPLY` is set to `true` (default) the patch is
#    automatically applied.
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
SWIFTFORMAT="$(which swiftformat)"

# set swiftformat config location
CONFIG="$(cd "$(dirname "$0")/.."; pwd)/.swiftformat"

# toplevel folder
TOP_LEVEL="$(cd "$(dirname "$0")/.."; pwd)"

SWIFT_VERSION="5"

# remove any older patches from previous commits. Set to true or false.
# DELETE_OLD_PATCHES=false
DELETE_OLD_PATCHES=true

# only parse files with the extensions in FILE_EXTS. Set to true or false.
# if false every changed file in the commit will be parsed with Uncrustify.
# if true only files matching one of the extensions are parsed with Uncrustify.
# PARSE_EXTS=true
PARSE_EXTS=true

# file types to parse. Only effective when PARSE_EXTS is true.
# FILE_EXTS=".c .h .cpp .hpp"
FILE_EXTS=".swift"

# when changes are found, apply those change automatically
AUTO_APPLY=true
##################################################################
# There should be no need to change anything below this line.

. "$(dirname -- "$0")/canonicalize_filename.sh"

# exit on error
set -e

# check whether the given file matches any of the set extensions
matches_extension() {
    local filename="$(basename -- "$1")"
    local extension=".${filename##*.}"
    local ext

    for ext in $FILE_EXTS; do [ "$ext" = "$extension" ] && return 0; done

    return 1
}

# necessary check for initial commit
if git rev-parse --verify HEAD >/dev/null 2>&1 ; then
    against=HEAD
else
    # Initial commit: diff against an empty tree object
    against=4b825dc642cb6eb9a060e54bf8d69288fbee4904
fi

# make sure the config file and executable are correctly set
if [ ! -f "$CONFIG" ] ; then
    printf "Error: swiftformat config file not found.\n"
    printf "Set the correct path in $(canonicalize_filename "$0").\n"
    exit 0
fi

if ! command -v "$SWIFTFORMAT" > /dev/null ; then
    printf "Error: swiftformat executable not found.\n"
    printf "Set the correct path in $(canonicalize_filename "$0").\n"
    exit 1
fi

# create a filename to store our generated patch
prefix="pre-commit-swiftformat"
suffix="$(date +%C%y-%m-%d_%Hh%Mm%Ss)"
patch="/tmp/$prefix-$suffix.patch"

# clean up any older uncrustify patches
$DELETE_OLD_PATCHES && rm -f /tmp/$prefix*.patch

# create one patch containing all changes to the files
# sed to remove quotes around the filename, if inserted by the system
# (done sometimes, if the filename contains special characters, like the quote itself)
git diff --diff-filter=ACMR --name-only $against -- | \
sed -e 's/^"\(.*\)"$/\1/' | \
while read file
do
    # ignore file if we do check for file extensions and the file
    # does not match any of the extensions specified in $FILE_EXTS
    if $PARSE_EXTS && ! matches_extension "$file"; then
        continue;
    fi

    # escape special characters in the source filename:
    # - '\': backslash needs to be escaped
    # - '*': used as matching string => '*' would mean expansion
    #        (curiously, '?' must not be escaped)
    # - '[': used as matching string => '[' would mean start of set
    # - '|': used as sed split char instead of '/', so it needs to be escaped
    #        in the filename
    # printf %s particularly important if the filename contains the % character
    file_escaped_source=$(printf "%s" "$file" | sed -e 's/[\*[|]/\\&/g')

    # escape special characters in the target filename:
    # phase 1 (characters escaped in the output diff):
    #     - '\': backslash needs to be escaped in the output diff
    #     - '"': quote needs to be escaped in the output diff if present inside
    #            of the filename, as it used to bracket the entire filename part
    # phase 2 (characters escaped in the match replacement):
    #     - '\': backslash needs to be escaped again for sed itself
    #            (i.e. double escaping after phase 1)
    #     - '&': would expand to matched string
    #     - '|': used as sed split char instead of '/'
    # printf %s particularly important if the filename contains the % character
    file_escaped_target=$(printf "%s" "$file" | sed -e 's/[\"]/\\&/g' -e 's/[\&|]/\\&/g')

    # Format our sourcefile, create a patch with diff and append it to our $patch
    # The sed call is necessary to transform the patch from
    #    --- $file timestamp
    #    +++ - timestamp
    # to both lines working on the same file and having a a/ and b/ prefix.
    # Else it can not be applied with 'git apply'.
    full_file_path=$(printf "$TOP_LEVEL/$file")
    cat "$full_file_path" | "$SWIFTFORMAT" --config "$CONFIG" --swiftversion "$SWIFT_VERSION" | \
        diff -u -- "$full_file_path" - | \
        sed -e "1s|--- $file_escaped_source|--- \"a/$file_escaped_target\"|" -e "2s|+++ -|+++ \"b/$file_escaped_target\"|" >> "$patch"
done

# if no patch has been generated all is ok, clean up the file stub and exit
if [ ! -s "$patch" ] ; then
    printf "Files in this commit comply with the swiftformat rules.\n"
    rm -f "$patch"
    exit 0
fi

if [ $AUTO_APPLY ] ; then
    git apply "$patch"
    exit 0
fi

# a patch has been created, notify the user and exit
printf "\nThe following differences were found between the code to commit "
printf "and the swiftformat rules:\n\n"
cat "$patch"

printf "\nYou can apply these changes with:\n git apply $patch\n"
printf "(may need to be called from the root directory of your repository)\n"
printf "Aborting commit. Apply changes and commit again or skip checking with"
printf " --no-verify (not recommended).\n"

exit 1
