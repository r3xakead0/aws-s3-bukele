<p align="center">
  <img src="bukele.gif" alt="AWS S3 Bukele project artwork" width="180">
</p>

# AWS S3 Compressed File Uploader

[English](README.md) | [Español](README.ES.md)

A small Bash utility that uploads a compressed file to a predefined Amazon S3 location. Before uploading, it validates the input and the AWS CLI, checks the selected AWS profile, and starts an AWS IAM Identity Center (AWS SSO) login when the current session is not valid.

## Features

- Validates that a file was provided and exists.
- Accepts `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, and `.tar.xz` archives.
- Verifies that the AWS CLI is installed.
- Uses a configurable AWS CLI profile and S3 prefix.
- Checks the current AWS identity before uploading.
- Opens an AWS SSO login flow when authentication is required.
- Stops immediately if a command fails.

> [!NOTE]
> The archive is uploaded as-is. The script does not extract its contents.

## Requirements

- Bash.
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and available in `PATH`.
- An AWS CLI profile configured for the target account. AWS CLI v2 is recommended for [AWS SSO authentication](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html).
- An existing S3 bucket.
- Permission to upload objects to the configured S3 location.

For an SSO-enabled profile, configure the AWS CLI first:

```bash
aws configure sso --profile my-profile
```

## Configuration

Edit the configuration values near the top of [`upload-to-s3.sh`](upload-to-s3.sh):

```bash
BUCKET="bucket-name"
AWS_PROFILE="default"
S3_PREFIX="backups"
```

| Variable | Purpose | Example |
| --- | --- | --- |
| `BUCKET` | Name of the destination S3 bucket | `company-archives` |
| `AWS_PROFILE` | AWS CLI profile used for authentication | `production` |
| `S3_PREFIX` | Destination path inside the bucket | `backups` |

The resulting destination follows this pattern:

```text
s3://<BUCKET>/<S3_PREFIX>/<archive-name>
```

For example, `photos-2026.zip` with bucket `company-archives` and prefix `backups` is uploaded to:

```text
s3://company-archives/backups/photos-2026.zip
```

## Usage

1. Clone the repository and enter its directory:

   ```bash
   git clone https://github.com/r3xakead0/aws-s3-bukele.git
   cd aws-s3-bukele
   ```

2. Update the configuration values in `upload-to-s3.sh`.

3. Make the script executable:

   ```bash
   chmod +x upload-to-s3.sh
   ```

4. Upload an archive:

   ```bash
   ./upload-to-s3.sh /path/to/photos-2026.zip
   ```

If the configured AWS session has expired, the script runs `aws sso login` and waits for authentication to complete before continuing.

## Required S3 permission

The AWS principal used by the selected profile needs `s3:PutObject` for the destination prefix. A minimal identity policy can look like this after replacing the example bucket and prefix:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::company-archives/backups/*"
    }
  ]
}
```

Review and test the policy before attaching it to a role or permission set.

## How it works

The script performs these steps:

1. Confirms that an input file was provided.
2. Confirms that the file exists.
3. Checks that the `aws` command is available.
4. Rejects unsupported archive extensions.
5. Calls `aws sts get-caller-identity` with the configured profile.
6. Runs `aws sso login` if the identity check fails.
7. Uploads the archive with `aws s3 cp`.

Because the script uses `set -euo pipefail`, it exits when a command fails, an undefined variable is referenced, or a pipeline fails.

## Troubleshooting

### `Error: File not found`

Check the file path. Paths containing spaces should be quoted:

```bash
./upload-to-s3.sh "/path/to/My Archive.zip"
```

### `Error: Unsupported compressed file format`

Use one of the supported extensions: `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, or `.tar.xz`.

### SSO login fails

Confirm that `AWS_PROFILE` matches an SSO-enabled profile in `~/.aws/config`, then test it directly:

```bash
aws sso login --profile my-profile
aws sts get-caller-identity --profile my-profile
```

### Upload is denied

Verify the bucket name, AWS account, selected profile, and `s3:PutObject` permission for the configured prefix. Also check the bucket policy and any required encryption settings.

## Limitations

- Configuration is stored in the script rather than passed through command-line options.
- Only one archive is uploaded per execution.
- The destination file name is the archive's base name.
- An existing object at the same S3 key can be overwritten if bucket versioning or policy controls do not prevent it.
- Automatic reauthentication assumes an AWS SSO-enabled profile.

## License

This project is licensed under the [MIT License](LICENSE).
