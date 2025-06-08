#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# THIS FILE IS USED IN THE Dockerfile

# Construct the final command to execute your application
# "$@" expands to all arguments passed to the entrypoint script (which come from CMD)
# "${CERT_PASSWORD}" will be correctly expanded by this shell script.
exec xec "$@" "${CERT_PASSWORD}" "${ROUTE}" "${BIND}" "${PROXIES}"