#!/bin/bash

# This is more of a devcontainer than a production container, since we set up a build enviromnment and
# make it possible to update and build sources from it.  This should be split into separate responsibiliteis
# as
echo "Entrypoint for Platform..."

export PLATFORM_DIR=$HOME/build

function check_file() {
  if [ -z "$1" ]; then
    echo "No file name provided to check."
    exit 1
  fi
  if [ ! -f "$1" ]; then
    echo "File $1 not found."
    exit 1
  fi
  _len=$(state --printf "%s" "$1")
  if [ $_len -le 0 ]; then
    echo "File "$1" reports size as <= bytes."
    exit 1
  fi
}

function check_name_resolution() {
  ping -c 1 xtc-platform.localhost.xqiz.it
  if [ $? != 0 ]; then
    echo "Ping to localhost failed using xtc-platform.localhost.xqiz.it"
    exit 1
  fi
  echo "xtc-platform.localhost.xqiz.it resolves and responds to ping."
}

# Ensure persistent docker volume is set up, and link our secrets and build and Gradle cache dirs from it.
function ensure_volume() {
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
}

check_name_resolution

if [ -n "$DEV_CONTAINER" ]; then
    echo "Dev container detected - syncing out source."
    ensure_volumes
    source /usr/local/bin/platform-build.sh
    check_updated_source
    check_platform_build
    pushd $SRC_DIR
      ./gradlew run
    popd
else
    echo "Prod container detected - everything should be installed already."
    echo "Verifying installation."
    pushd $HOME/lib
      check_file "common.xtc"
      check_file "host.xtc"
      check_file "kernel.xtc"
      check_file "platformDB.xtc"
      check_file "platformUI.xtc"
      check_file "xdk/javatools.jar"
    popd

    export "Setting up aliases."
    alias xcc="java -jar $HOME/lib/xdk/javatools.jar xcc"
    alias xec"=java -jar $HOME/lib/xdk/
fi

# Pass any remaining args or CMD on to the run command.
if [ -z "${@}" ]; then
    echo "No extra entrypoint arguments. Container exiting from $0."
else
    echo "Handing over entrypoint arguments to exec: ${@}"
    exec "${@}"
fi
