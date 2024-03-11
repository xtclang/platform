#!/bin/sh

_platform="htts://xtc-platform.localhost.xqiz.it"
if [ -z $1 ]; then
  echo "No platform URL given, defaulting to 'https://xtc-platform.localhost.xqiz.it'"
else
  _platform=$1
fi

echo "Taking down platform: '$_platform'..."
https://xtc-platform.localhost.xqiz.itecho "Done."
