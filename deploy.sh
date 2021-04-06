#!/bin/bash

## Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
## SPDX-License-Identifier: Apache-2.0

set -e

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts hdvp:-: OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "$OPT" in
    h | help )     help=true ;;
    d | debug )    debug=true ;;
    v | verbose )  verbose=true ;;
    p | profile )  needs_arg; profile="$OPTARG" ;;
    ??* )          die "Illegal option --$OPT" ;;  # bad long option
    ? )            exit 2 ;;  # bad short option (error reported via getopts)
  esac
done
shift $((OPTIND-1)) # remove parsed options and args from $@ list

if [ "$help" ]; then
  echo "Usage: $0 [d--profile"
  echo "Arguments:"
  echo "   -v, --verbose      Show debug logs"
  echo "   -d, --debug        Enable emission of additional debugging information"
  echo "   -p, --profile      Use the indicated AWS profile "
  echo
  echo 'Example: ./deploy.sh -v --profile=example'
  exit 1
fi

CDKOPTS=""
if [ "$verbose" ]; then
  CDKOPTS="$CDKOPTS --verbose"
fi
if [ "$debug" ]; then
  CDKOPTS="$CDKOPTS --debug"
fi
if [ "$profile" ]; then
  CDKOPTS="$CDKOPTS --profile $profile"
fi

if [ -f "cdk.context.json" ]; then
    echo ""
    echo "INFO: Removing cdk.context.json"
    rm cdk.context.json
else
    echo ""
    echo "INFO: cdk.context.json not present, nothing to remove"
fi
if [ ! -f "package-lock.json" ]; then
    echo ""
    echo "Installing Packages"
    echo ""
    npm install
fi
if [ ! -d "front-end-resources/react-meeting/build" ]; then
    echo ""
    echo "Creating front-end-resources/react-meeting/build directory"
    echo ""
    mkdir -p front-end-resources/react-meeting/build
fi
echo ""
echo "Building CDK"
echo ""
npm run build
echo ""
echo "Deploying Back End"
echo ""
cdk deploy $CDKOPTS MeetingBackEnd -O front-end-resources/react-meeting/src/cdk-outputs.json
echo ""
echo "Building React App"
echo ""
cd front-end-resources/react-meeting
if [ ! -f "package-lock.json" ]; then
    echo ""
    echo "Installing Packages"
    echo ""
    npm install --legacy-peer-deps
fi
npm run build
cd -
echo ""
echo "Deploying Front End"
echo ""
cdk deploy $CDKOPTS MeetingFrontEnd