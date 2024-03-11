#!/bin/bash

# This is more of a devcontainer than a production container, since we set up a build enviromnment and
# make it possible to update and build sources from it.  This should be split into separate responsibiliteis
# as
echo "Entrypoint for Platform..."

function check_name_resolution() {
  ping -c 1 xtc-platform.localhost.xqiz.it
  if [ $? != 0 ]; then
    echo "Ping to localhost failed using xtc-platform.localhost.xqiz.it"
    exit 1
  fi
  echo "xtc-platform.localhost.xqiz.it resolves and responds to ping."
}

# Under root build we have have src and .gradle

export PLATFORM_DIR=$HOME/build

# Ensure persistent docker volume is set up, and link our secrets and build and Gradle cache dirs from it.
sudo chown -R $XTC_USER:$XTC_USER /persistent
ln -s /persistent $PLATFORM_DIR
export GRADLE_USER_HOME=$HOME/.gradle
if [ ! -d $PLATFORM_DIR/gradle ]; then
  echo "Creating Gradle user home: $GRADLE_USER_HOME"
  mkdir -p $PLATFORM_DIR/gradle
fi
ln -s $PLATFORM_DIR/gradle $GRADLE_USER_HOME
if [ ! -e $GRADLE_USER_HOME/gradle.properties ]; then
  echo "Linking gradle.properties"
  ln -s /var/run/secrets/gradle_properties $GRADLE_USER_HOME/gradle.properties
fi

source /usr/local/bin/platform-build.sh

check_name_resolution
check_updated_source
check_platform_build

# Pass any remaining args or CMD on to the run command.
if [ -z "${@}" ]; then
    echo "No extra entrypoint arguments. Container exiting from $0."
else
    echo "Handing over entrypoint arguments to exec: ${@}"
    exec "${@}"
fi
