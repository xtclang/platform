#!/bin/bash

echo "Ensuring the platform is built."

export SRC_DIR=$PLATFORM_DIR/src

function clone_platform() {
  pushd $PLATFORM_DIR
    echo "Cloning to platform"
    git clone --branch $GITHUB_BRANCH_PLATFORM --depth=1 https://github.com/xtclang/platform.git src
    echo "Writing last commit"
    pushd $SRC_DIR
      git rev-parse --verify HEAD > last_commit
    popd
  popd
}

function check_updated_source() {
  echo "Checking for $SRC_DIR"
  ls -lart $PLATFORM_DIR
  if [ -e $SRC_DIR ]; then
    echo "Found existing source."

    pushd $SRC_DIR
      _last_commit="unknown"
      if [ -e last_commit ]; then
        _last_commit=$(cat last_commit)
      fi
      _last_remote_commit=$(git ls-remote https://github.com/xtclang/platform.git platform-xtcplugin | awk '{ print $1 }')
    popd

    echo "last_commit       : $_last_commit"
    echo "last_remote_commit: $_last_remote_commit"
    if [ "$_last_commit" != "$_last_remote_commit" ]; then
      echo "Existing source out of date. REMOVING existing source dir: $SRC_DIR"
      rm -fr $SRC_DIR
      clone_platform
    else
      echo "Existing platform is up date - good!"
    fi
  else
    echo "Cloning new platform (no previous version found)."
    clone_platform
  fi
}

# Verify that the platform is built
function build_platform() {
  pushd $SRC_DIR
    ./gradlew build
  popd
}
