#!/bin/sh

#  ci_pre_xcodebuild.sh
#  CommonsFinder
#
#  Created by Tom Brewe on 11.06.26.
#

# cd to the project directory (adjust path as needed)
cd $CI_PRIMARY_REPOSITORY_PATH/CommonsFinder

# Writes the Xcode Cloud environment variable into the Release xcconfig
# This overrides the placeholder value before Xcode builds
echo "OAUTH_CLIENT_ID = ${OAUTH_CLIENT_ID}" >> Release.xcconfig

exit 0
