#!/bin/sh
#
# Xcode Cloud runs this right after it clones the repo, before the build.
#
# The project carries a hardcoded CURRENT_PROJECT_VERSION, and App Store
# Connect rejects an upload whose build number it has already seen. So the
# build number is stamped in here, into the throwaway CI checkout. Nothing is
# committed and the number in the repo stays as a placeholder.
#
# The offset matters: CI_BUILD_NUMBER starts at 1 for a workflow's first build,
# but builds 1, 2 and 3 were already uploaded by hand. Adding OFFSET puts every
# Xcode Cloud build well clear of those while staying monotonic.
set -e

OFFSET=100

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "No CI_BUILD_NUMBER set, so this is not an Xcode Cloud build. Leaving the build number alone."
  exit 0
fi

PBXPROJ="$CI_PRIMARY_REPOSITORY_PATH/ios/DRILL.xcodeproj/project.pbxproj"
if [ ! -f "$PBXPROJ" ]; then
  echo "error: no project file at $PBXPROJ" >&2
  exit 1
fi

BUILD_NUMBER=$((CI_BUILD_NUMBER + OFFSET))

sed -i '' -E "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "$PBXPROJ"

echo "Stamped build number ${BUILD_NUMBER} (CI_BUILD_NUMBER ${CI_BUILD_NUMBER} + ${OFFSET}):"
grep -n "CURRENT_PROJECT_VERSION" "$PBXPROJ" | sed 's/^/  /'
