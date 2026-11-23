<p align="center">
  <img src="bukele.gif" alt="AWS S3 Bukele project artwork" width="180">
</p>

# AWS S3 Compressed File Uploader

[English](README.md) | [Español](README.ES.md) | [Português](README.PT.md)

A cross-platform command-line utility for uploading compressed files to Amazon S3, with Bash support for Linux and macOS and PowerShell support for Windows. Both implementations validate the input, check the selected AWS profile, renew an AWS IAM Identity Center (AWS SSO) session when necessary, and upload the archive without extracting it.

## Features

- Supports `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, and `.tar.xz` files.
- Runs on Linux and macOS with Bash and on Windows with PowerShell.
- Accepts configuration through command-line options or environment variables.
- Supports an optional S3 storage class, using `STANDARD` by default.
- Validates the archive, bucket configuration, and AWS CLI installation.
- Checks the current AWS identity before uploading.
- Starts an AWS SSO login flow when the session is unavailable or expired.
- Normalizes leading and trailing slashes in the destination prefix.
- Includes dependency-free integration tests, ShellCheck validation, and PSScriptAnalyzer validation.

> [!NOTE]
> The archive is uploaded as-is. Its contents are not extracted.

## Project structure

```text
.
├── .github/workflows/ci.yml  # Automated lint and test workflow
├── bin/upload-to-s3.sh       # Bash command-line application
├── bin/upload-to-s3.ps1      # PowerShell command-line application
├── tests/                    # Bash and PowerShell integration tests
├── .editorconfig             # Shared editor formatting rules
├── .env.example              # Configuration template
├── .gitattributes            # Consistent Git line endings
├── .gitignore                # Local files excluded from Git
├── Makefile                  # Development and execution commands
├── README.md                 # English documentation
├── README.ES.md              # Spanish documentation
├── README.PT.md              # Portuguese documentation
└── LICENSE                   # MIT license
```

## Requirements

### Runtime

- Bash on Linux or macOS, or PowerShell 5.1 or later on Windows.
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
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) to lint PowerShell locally.

## Quick start

Clone the repository:

```bash
git clone https://github.com/r3xakead0/aws-s3-bukele.git
cd aws-s3-bukele
```

### Linux and macOS

Upload an archive with Bash:

```bash
./bin/upload-to-s3.sh \
  --bucket company-archives \
  --profile production \
  --prefix backups \
  /path/to/photos-2026.zip
```

### Windows

Upload the same archive with PowerShell:

```powershell
.\bin\upload-to-s3.ps1 `
  -Bucket company-archives `
  -Profile production `
  -Prefix backups `
  -Archive C:\Backups\photos-2026.zip
```

The resulting object is stored at:

```text
s3://company-archives/backups/photos-2026.zip
```

Because no storage class was specified, the object uses `STANDARD`.

## Configuration

Command-line options take precedence over environment variables.

| Bash / PowerShell option | Environment variable | Default | Purpose |
| --- | --- | --- | --- |
| `--bucket`, `-b` / `-Bucket` | `S3_BUCKET` | Required | Destination S3 bucket |
| `--profile`, `-p` / `-Profile` | `AWS_PROFILE` | `default` | AWS CLI profile |
| `--prefix` / `-Prefix` | `S3_PREFIX` | `backups` | Destination prefix inside the bucket |
| `--storage-class`, `-s` / `-StorageClass` | `S3_STORAGE_CLASS` | `STANDARD` | S3 storage class for the uploaded object |

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
./bin/upload-to-s3.sh /path/to/photos-2026.zip
```

Or use the Make target, which loads `.env` when the file exists:

```bash
make upload FILE=/path/to/photos-2026.zip
```

The `.env` file is ignored by Git so local configuration is not committed accidentally.

In PowerShell, set the same configuration as process environment variables:

```powershell
$env:S3_BUCKET = 'company-archives'
$env:AWS_PROFILE = 'production'
$env:S3_PREFIX = 'backups'
$env:S3_STORAGE_CLASS = 'STANDARD'

.\bin\upload-to-s3.ps1 -Archive C:\Backups\photos-2026.zip
```

### Storage classes

The storage class is optional. When neither `--storage-class` nor `S3_STORAGE_CLASS` is provided, the application explicitly uploads the object using `STANDARD`.

Supported values are:

- `STANDARD`
- `REDUCED_REDUNDANCY`
- `STANDARD_IA`
- `ONEZONE_IA`
- `INTELLIGENT_TIERING`
- `GLACIER`
- `DEEP_ARCHIVE`
- `GLACIER_IR`

For example:

```bash
./bin/upload-to-s3.sh \
  --bucket company-archives \
  --storage-class STANDARD_IA \
  /path/to/photos-2026.zip
```

PowerShell uses the equivalent `-StorageClass` parameter:

```powershell
.\bin\upload-to-s3.ps1 `
  -Bucket company-archives `
  -StorageClass STANDARD_IA `
  -Archive C:\Backups\photos-2026.zip
```

Choose a class according to the access pattern, retrieval requirements, minimum storage duration, and cost of the object. See the [Amazon S3 storage class guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html) for details.

## CLI reference

### Bash

```text
Usage: upload-to-s3.sh [options] <compressed-file>

Options:
  -b, --bucket NAME    Destination S3 bucket (or S3_BUCKET).
  -p, --profile NAME   AWS CLI profile (default: default).
      --prefix PATH    Destination prefix (default: backups).
  -s, --storage-class CLASS
                        S3 storage class (default: STANDARD).
  -h, --help           Show the help message.
```

Display the current help directly from the executable:

```bash
./bin/upload-to-s3.sh --help
```

### PowerShell

```text
Usage: upload-to-s3.ps1 [options] -Archive <compressed-file>

Options:
  -Bucket NAME          Destination S3 bucket (or S3_BUCKET).
  -Profile NAME         AWS CLI profile (default: default).
  -Prefix PATH          Destination prefix (default: backups).
  -StorageClass CLASS   S3 storage class (default: STANDARD).
  -Archive FILE         Compressed file to upload.
  -Help                 Show the help message.
```

```powershell
.\bin\upload-to-s3.ps1 -Help
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

Both applications:

1. Parse command-line options and environment variables.
2. Validate the bucket, storage class, input file, and supported extension.
3. Confirm that the AWS CLI is available.
4. Call `aws sts get-caller-identity` with the selected profile.
5. Run `aws sso login` and verify the identity again if the first check fails.
6. Build the destination URI and upload the archive with `aws s3 cp` and the selected storage class.

The Bash script uses `set -Eeuo pipefail`; the PowerShell script uses strict mode and terminating errors. Unexpected failures stop execution in both implementations.

## Development

Run the integration tests with the mocked AWS CLI:

```bash
make test
```

Run the PowerShell tests on a system with PowerShell 7:

```bash
make test-powershell
```

Or run them directly from PowerShell:

```powershell
.\tests\upload-to-s3-test.ps1
```

Run PSScriptAnalyzer:

```powershell
Invoke-ScriptAnalyzer -Path .\bin\upload-to-s3.ps1 -Severity Warning,Error
```

Run ShellCheck:

```bash
make lint
```

Run all Bash quality checks:

```bash
make check
```

GitHub Actions runs Bash lint and tests on Ubuntu, and PowerShell lint and tests on Windows. Neither test suite contacts AWS.

## Troubleshooting

### `S3 bucket is required`

Pass `--bucket` or set `S3_BUCKET` before running the command.

### `File not found`

Check the archive path. Quote paths that contain spaces:

```bash
./bin/upload-to-s3.sh --bucket company-archives "/path/to/My Archive.zip"
```

```powershell
.\bin\upload-to-s3.ps1 -Bucket company-archives -Archive 'C:\Backups\My Archive.zip'
```

### `Unsupported compressed file format`

Use `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, or `.tar.xz`.

### `Unsupported S3 storage class`

Use one of the values listed in [Storage classes](#storage-classes). Values are case-sensitive.

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
