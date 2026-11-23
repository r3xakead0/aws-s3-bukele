
#!/usr/bin/env bash

set -euo pipefail

# Configuration
BUCKET="bucket-name"  # Replace with your S3 bucket name
AWS_PROFILE="default"
S3_PREFIX="backups"

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <compressed-file>"
    exit 1
fi

FILE="$1"

# Validate file
if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# Validate AWS CLI
if ! command -v aws &>/dev/null; then
    echo "Error: AWS CLI is not installed."
    exit 1
fi

# Validate compressed file extension
if [[ ! "$FILE" =~ \.(zip|tar\.gz|tgz|tar\.bz2|tar\.xz)$ ]]; then
    echo "Error: Unsupported compressed file format."
    exit 1
fi

FILENAME=$(basename "$FILE")
S3_PATH="s3://${BUCKET}/${S3_PREFIX}/${FILENAME}"

echo "Checking AWS SSO session..."

# Authenticate with AWS SSO if necessary
if ! aws sts get-caller-identity \
    --profile "$AWS_PROFILE" &>/dev/null; then

    echo "AWS session expired. Starting SSO login..."
    aws sso login --profile "$AWS_PROFILE"
fi

# Upload file
echo "Uploading: $FILE"
echo "Destination: $S3_PATH"

aws s3 cp "$FILE" "$S3_PATH" \
    --profile "$AWS_PROFILE"

echo "Upload completed successfully!"
