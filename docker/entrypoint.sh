#!/bin/bash

echo "Entrypoint for Platform..."

# Under root build we have have src and .gradle
sudo chown -R $XTC_USER:$XTC_USER /cache

if [ ! -e $HOME/build ]; then
  echo "Linking cache volume as $HOME/build"
  ln -s /cache $HOME/build
fi

export GRADLE_USER_HOME=$HOME/build/.gradle
if [ ! -d $GRADLE_USER_HOME ]; then
  echo "Creating Gradle user home: $GRADLE_USER_HOME"
  mkdir -p $GRADLE_USER_HOME
  ln -s /var/run/secrets/gradle_properties $GRADLE_USER_HOME/gradle.properties
fi


source /usr/local/bin/platform-build.sh

check_updated_source

# XTC user should be sudoer
# Port forwaring should just be in the container???
#echo "User $USER executing pfctl under sudo privileges..."
#sudo pfctl -evf ~$XQIZIT_HOME/platform/port-forwarding.conf
#echo "Done."

#
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

# TODO Here is where we really want snapshot releases.
# TODO Right now the git clone is part of the container build. We should not do that, or at least map it to a reusable volume.
#    First we just want to check that docker works for it, though.
#git clone --branch $GITHUB_BRANCH_PLATFORM --depth=1 https://github.com/xtclang/platform.git
#git clone --branch $GITHUB_BRANCH_XVM --depth=1 https://github.com/xtclang/xvm.git

if [ -z "${@}" ]; then
    echo "No extra entrypoint arguments. Container exiting from $0."
else
    echo "Handing over entrypoint arguments to exec: ${@}"
    exec "${@}"
fi
