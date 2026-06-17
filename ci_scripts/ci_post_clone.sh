#!/bin/sh

# Xcode Cloud post-clone step.
#
# Config/Secrets.xcconfig is gitignored (it holds API keys), so a fresh Xcode
# Cloud checkout doesn't contain it — and the project references it as a base
# configuration, so the build fails with:
#   "Unable to open base configuration reference file .../Config/Secrets.xcconfig"
#
# This script recreates that file from a workflow environment variable.
#
# Required setup (one-time, in App Store Connect):
#   Xcode Cloud → Manage Workflows → your workflow → Environment →
#   add a SECRET Environment Variable named GOOGLE_PLACES_API_KEY.

set -e

if [ -z "$GOOGLE_PLACES_API_KEY" ]; then
  echo "error: GOOGLE_PLACES_API_KEY is not set. Add it as a secret Environment Variable in the Xcode Cloud workflow." >&2
  exit 1
fi

SECRETS_FILE="$CI_PRIMARY_REPOSITORY_PATH/Config/Secrets.xcconfig"
mkdir -p "$(dirname "$SECRETS_FILE")"

cat > "$SECRETS_FILE" <<EOF
GOOGLE_PLACES_API_KEY = ${GOOGLE_PLACES_API_KEY}
EOF

echo "Generated $SECRETS_FILE for the Xcode Cloud build."
