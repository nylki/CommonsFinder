#!/bin/sh

#  ci_pre_xcodebuild.sh
#  CommonsFinder
#
#  Created by Tom Brewe on 11.06.26.
#

# Writes the Xcode Cloud environment variable into the Release xcconfig
# This overrides the placeholder value before Xcode builds
if [ -z "${OAUTH_CLIENT_ID}" ]; then
    echo "error: OAUTH_CLIENT_ID environment variable is not set" >&2
    exit 1
fi

echo "OAUTH_CLIENT_ID = ${OAUTH_CLIENT_ID}" >> "$CI_PRIMARY_REPOSITORY_PATH/Release.xcconfig"

exit 0
