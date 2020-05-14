#!/bin/bash
# set -ex

## Sets the following environment variables:
##
## XBV_PROJECT_VERSION -> CFBundleShortVersionString
## XBV_PROJECT_BUILD -> CFBundleVersion

## Code based on
## https://github.com/denys-meloshyn/bitrise-step-git-tag-project-version-and-build-number
## by Denys Meloshyn.

read_dom() {
  local IFS=\>
  read -d \< ENTITY CONTENT
}

find_info_plist() {
  local result=$(grep -rl 'LaunchScreen' --include 'Info.plist' --exclude-dir 'Carthage' --exclude 'Pods' . | \
    awk -F: '{"date -r \""$1"\" +\"%F %R\"" | getline d; print d,$0}' | \
    sort -r | \
    cut -c18- | \
    sed -e "s/^.\///" -e "s/^\///" | \
    head -n 1)

  echo "$result"
}

find_xcodeproj() {
  local result=$(find . -name '*.xcodeproj' -maxdepth 1 -not -path "./.*" -not -path "./Carthage/*" -not -path "./Pods/*" | \
    sed -e "s/^.\///" -e "s/^\///" | \
    head -n 1)

  echo "$result"
}

CFBundleVersion=""
CFBundleVersionKey=false

CFBundleShortVersionString=""
CFBundleShortVersionStringKey=false

if [ -z "$info_plist_path" ]; then
  # If plist_path is not defined, it tries to find it before aborting
  info_plist_path=$(find_info_plist)

  if [ -z "$info_plist_path" ]; then
    echo "info_plist_path is empty"
    exit 1
  fi 

  echo "Info.plist: $info_plist_path"
fi

while read_dom; do
  if [[ $CFBundleShortVersionStringKey == true ]]; then
    if [ $ENTITY = "string" ]; then
      CFBundleShortVersionString=$CONTENT
      CFBundleShortVersionStringKey=false
    fi
  fi

  if [[ $CFBundleVersionKey == true ]]; then
    if [ $ENTITY = "string" ]; then
      CFBundleVersion=$CONTENT
      CFBundleVersionKey=false
    fi
  fi

  if [[ $CONTENT == "CFBundleShortVersionString" ]]; then
    CFBundleShortVersionStringKey=true
  fi

  if [[ $CONTENT == "CFBundleVersion" ]]; then
    CFBundleVersionKey=true
  fi
done <"$info_plist_path"

if [ -z "$CFBundleShortVersionString" ]; then
  echo "CFBundleShortVersionString is empty"
  exit 1
fi

if [ -z "$CFBundleVersion" ]; then
  echo "CFBundleVersion is empty"
  exit 1
fi

if [[ $CFBundleVersion == *CURRENT_PROJECT_VERSION* ]]; then
  if [ -z "$project_path" ]; then
    # If xcodeproj_path is not defined, it tries to find it before aborting
    project_path=$(find_xcodeproj)

    if [ -z "$project_path" ]; then
      echo "project_path is empty"
      exit 1
    fi

    echo "XCODEPROJ: $project_path/project.pbxproj"
  fi

  CURRENT_PROJECT_VERSION=""
  LINES=$(sed -n '/CURRENT_PROJECT_VERSION/=' "$project_path/project.pbxproj")
  for LINE in $LINES; do
    CURRENT_PROJECT_VERSION=$(sed -n "$LINE"p "$project_path"/project.pbxproj)
    CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION#*= }"
    CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION%;}"
  done

  if [ -z "$CURRENT_PROJECT_VERSION" ]; then
    echo "CURRENT_PROJECT_VERSION is empty"
    exit 1
  fi

  CFBundleVersion=$CURRENT_PROJECT_VERSION
fi

if [[ $CFBundleShortVersionString == *MARKETING_VERSION* ]]; then
  if [ -z "$project_path" ]; then
    echo "project_path is empty"
    exit 1
  fi

  MARKETING_VERSION=""
  LINES=$(sed -n '/MARKETING_VERSION/=' "$project_path/project.pbxproj")
  for LINE in $LINES; do
    MARKETING_VERSION=$(sed -n "$LINE"p "$project_path"/project.pbxproj)
    MARKETING_VERSION="${MARKETING_VERSION#*= }"
    MARKETING_VERSION="${MARKETING_VERSION%;}"
  done

  if [ -z "$MARKETING_VERSION" ]; then
    echo "MARKETING_VERSION is empty"
    exit 1
  fi

  CFBundleShortVersionString=$MARKETING_VERSION
fi

echo "XBV_PROJECT_VERSION: ${CFBundleShortVersionString}"
echo "XBV_PROJECT_BUILD: ${CFBundleVersion}"

envman add --key XBV_PROJECT_VERSION --value $CFBundleShortVersionString
envman add --key XBV_PROJECT_BUILD --value $CFBundleVersion

#
# --- Export Environment Variables for other Steps:
# You can export Environment Variables for other Steps with
#  envman, which is automatically installed by `bitrise setup`.
# A very simple example:

# Envman can handle piped inputs, which is useful if the text you want to
# share is complex and you don't want to deal with proper bash escaping:
#  cat file_with_complex_input | envman add --KEY EXAMPLE_STEP_OUTPUT
# You can find more usage examples on envman's GitHub page
#  at: https://github.com/bitrise-io/envman

#
# --- Exit codes:
# The exit code of your Step is very important. If you return
#  with a 0 exit code `bitrise` will register your Step as "successful".
# Any non zero exit code will be registered as "failed" by `bitrise`.
