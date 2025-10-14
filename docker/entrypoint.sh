#!/bin/sh
set -e # Exit immediately if a command exits with a non-zero status

if [ -z "${PASSWORD}" ]; then
  echo "----------------------------------------------------------------------"
  echo "ERROR: The PASSWORD environment variable is required."
  echo "Please provide it using the '-e' flag during 'docker run'."
  echo "Example: docker run -e PASSWORD=[password] your-image-name"
  echo "----------------------------------------------------------------------"
  exit 1 # Exit with a non-zero status code to indicate failure
fi

# Set JVM options for heap size (default 2GB if not specified)
export JAVA_OPTS="${JAVA_OPTS:--Xmx2g -Xms512m}"

# Construct the final command to execute your application
# "$@" expands to all arguments passed to the entrypoint script (which come from CMD)
# "${PASSWORD}" will be correctly expanded by this shell script.
exec xec "$@" "${PASSWORD}"
