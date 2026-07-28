#!/bin/sh
set -e

# Keep serverless-init as the main process and pass the application command to it.
exec /dd/datadog-init "$@"
