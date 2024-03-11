#!/bin/bash

echo "Ensuring the platform is built."


function clone_platform() {
  pushd $HOME/build
  echo "Cloning to platform"
  git clone --branch $GITHUB_BRANCH_PLATFORM --depth=1 https://github.com/xtclang/platform.git platform
  echo "Writing last commit"
  pushd platform
  git rev-parse --verify HEAD > last_commit
  popd
  popd
}

function check_updated_source() {
  if [ -e $HOME/build/platform ]; then
    echo "Found existing source."

    pushd $HOME/build/platform
    _last_commit="unknown"
    if [ -e last_commit ]; then
      _last_commit=$(cat last_commit)
    fi
    _last_remote_commit=$(git rev-parse --verify HEAD)
    popd

    echo "last_commit       : $_last_commit"
    echo "last_remote_commit: $_last_remote_commit"
    if [ "$_last_commit" != "$_last_remote_commit" ]; then
      echo "Existing source out of date."
      rm -fr $HOME/build/platform
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
  pushd $HOME/build/platform
  ./gradlew build
  popd
}
