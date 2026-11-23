<p align="center">
  <img src="bukele.gif" alt="AWS S3 Bukele project artwork" width="180">
</p>

# AWS S3 Compressed File Uploader

[English](README.md) | [Español](README.ES.md)

A focused Bash command-line utility for uploading compressed files to Amazon S3. It validates the input, checks the selected AWS profile, renews an AWS IAM Identity Center (AWS SSO) session when necessary, and uploads the archive without extracting it.

## Features

- Supports `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, and `.tar.xz` files.
- Accepts configuration through command-line options or environment variables.
- Validates the archive, bucket configuration, and AWS CLI installation.
- Checks the current AWS identity before uploading.
- Starts an AWS SSO login flow when the session is unavailable or expired.
- Normalizes leading and trailing slashes in the destination prefix.
- Includes dependency-free integration tests and automated ShellCheck validation.

> [!NOTE]
> The archive is uploaded as-is. Its contents are not extracted.

## Project structure

```text
.
├── .github/workflows/ci.yml  # Automated lint and test workflow
├── bin/upload-to-s3          # Command-line application
├── tests/                    # Integration tests with a mocked AWS CLI
├── .editorconfig             # Shared editor formatting rules
├── .env.example              # Configuration template
├── .gitattributes            # Consistent Git line endings
├── .gitignore                # Local files excluded from Git
├── Makefile                  # Development and execution commands
├── README.md                 # English documentation
├── README.ES.md              # Spanish documentation
└── LICENSE                   # MIT license
```

## Requirements

### Runtime

- Bash.
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) available in `PATH`.
- An existing S3 bucket.
- An AWS CLI profile with access to the destination.
- `s3:PutObject` permission for the configured S3 prefix.

For an SSO-enabled profile, configure the AWS CLI first:

```bash
aws configure sso --profile my-profile
```

### Development

- `make` to run the project tasks.
- [ShellCheck](https://www.shellcheck.net/) to run the linter.

## Quick start

1. Clone the repository:

   ```bash
   git clone https://github.com/r3xakead0/aws-s3-bukele.git
   cd aws-s3-bukele
   ```

2. Upload an archive by providing the configuration explicitly:

   ```bash
   ./bin/upload-to-s3 \
     --bucket company-archives \
     --profile production \
     --prefix backups \
     /path/to/photos-2026.zip
   ```

The resulting object is stored at:

```text
s3://company-archives/backups/photos-2026.zip
```

## Configuration

Command-line options take precedence over environment variables.

| CLI option | Environment variable | Default | Purpose |
| --- | --- | --- | --- |
| `--bucket`, `-b` | `S3_BUCKET` | Required | Destination S3 bucket |
| `--profile`, `-p` | `AWS_PROFILE` | `default` | AWS CLI profile |
| `--prefix` | `S3_PREFIX` | `backups` | Destination prefix inside the bucket |

### Using an environment file

Copy the provided template and update its values:

```bash
cp .env.example .env
```

The CLI does not load `.env` implicitly. Either export it in the current shell:

```bash
set -a
source .env
set +a
./bin/upload-to-s3 /path/to/photos-2026.zip
```

Or use the Make target, which loads `.env` when the file exists:

```bash
make upload FILE=/path/to/photos-2026.zip
```

The `.env` file is ignored by Git so local configuration is not committed accidentally.

## CLI reference

```text
Usage: upload-to-s3 [options] <compressed-file>

Options:
  -b, --bucket NAME    Destination S3 bucket (or S3_BUCKET).
  -p, --profile NAME   AWS CLI profile (default: default).
      --prefix PATH    Destination prefix (default: backups).
  -h, --help           Show the help message.
```

Display the current help directly from the executable:

```bash
./bin/upload-to-s3 --help
```

## Required S3 permission

The selected AWS principal needs `s3:PutObject` for the destination prefix. Replace the example bucket and prefix before using this identity policy:

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

The application:

1. Parses command-line options and environment variables.
2. Validates the bucket, input file, and supported extension.
3. Confirms that the AWS CLI is available.
4. Calls `aws sts get-caller-identity` with the selected profile.
5. Runs `aws sso login` and verifies the identity again if the first check fails.
6. Builds the destination URI and uploads the archive with `aws s3 cp`.

The script uses `set -Eeuo pipefail` so unexpected command, variable, and pipeline failures stop execution.

## Development

Run the integration tests with the mocked AWS CLI:

```bash
make test
```

Run ShellCheck:

```bash
make lint
```

Run every local quality check:

```bash
make check
```

The same checks run automatically for pushes and pull requests through GitHub Actions. The test suite never contacts AWS.

## Troubleshooting

### `S3 bucket is required`

Pass `--bucket` or set `S3_BUCKET` before running the command.

### `File not found`

Check the archive path. Quote paths that contain spaces:

```bash
./bin/upload-to-s3 --bucket company-archives "/path/to/My Archive.zip"
```

### `Unsupported compressed file format`

Use `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, or `.tar.xz`.

### SSO login fails

Confirm that the selected profile is configured for AWS SSO, then test it directly:

```bash
aws sso login --profile my-profile
aws sts get-caller-identity --profile my-profile
```

### Upload is denied

Verify the bucket, AWS account, selected profile, `s3:PutObject` permission, bucket policy, and encryption requirements.

## Limitations

- One archive is uploaded per execution.
- The destination object uses the archive's base file name.
- An existing object at the same key can be overwritten unless bucket versioning or policy controls prevent it.
- Automatic reauthentication assumes an AWS SSO-enabled profile.

## License

This project is licensed under the [MIT License](LICENSE).
