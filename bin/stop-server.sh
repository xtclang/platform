#!/bin/sh

curl -k -b cookies.txt -L -i -w '\n' -X POST https://xtc-platform.localhost.xqiz.it/host/shutdown
