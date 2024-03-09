#!/bin/bash

echo "Entrypoint for Platform..."

# XTC user should be sudoer
# Port forwaring should just be in the container???
#echo "User $USER executing pfctl under sudo privileges..."
#sudo pfctl -evf ~$XQIZIT_HOME/platform/port-forwarding.conf
#echo "Done."

#
# TODO: This is insane. We should just be setting up a localhost network.
# If we want xtc-platform.localhost.xqiz.it to pingback from the host, put it /etc/hosts
#
#   The domain name `xtc-platform.localhost.xqiz.it` should resolve to `127.0.0.1`. This allows the same xqiz.it
#   cloud-hosted platform to be self-hosted on the `localhost` loop-back address, enabling local and disconnected
#   development.
#
#   If that address fails to resolve you may need to change the rules on you DNS server. For example, for Verizon routers
#   you would need add an exception entry for `127.0.0.1` to your DNS Server settings: "Exceptions to DNS Rebind
#   Protection" (Advanced - Network Settings - DNS Server)

ping -c 1 xtc-platform.localhost.xqiz.it
if [ $? != 0 ]; then
  echo "Ping to localhost failed using xtc-platform.localhost.xqiz.it"
  exit 1
fi

if [ -z "${@}" ]; then
    echo "No extra entrypoint arguments. Container exiting from $0."
else
    echo "Handing over entrypoint arguments to exec: ${@}"
    exec "${@}"
fi
