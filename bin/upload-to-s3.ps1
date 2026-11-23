#requires -Version 5.1

<#
.SYNOPSIS
Uploads a compressed file to Amazon S3.

.DESCRIPTION
Validates a compressed file, verifies the selected AWS CLI profile, starts an
AWS IAM Identity Center (AWS SSO) login when required, and uploads the archive
without extracting it.

.PARAMETER Archive
Path to the compressed file to upload.

.PARAMETER Bucket
Destination S3 bucket. Falls back to the S3_BUCKET environment variable.

.PARAMETER AwsProfile
AWS CLI profile. Falls back to AWS_PROFILE and then to default.

.PARAMETER Prefix
Destination prefix. Falls back to S3_PREFIX and then to backups.

.PARAMETER StorageClass
S3 storage class. Falls back to S3_STORAGE_CLASS and then to STANDARD.

.EXAMPLE
./bin/upload-to-s3.ps1 -Bucket company-archives -Profile production -Archive C:\Backups\photos.zip

.EXAMPLE
./bin/upload-to-s3.ps1 -Bucket company-archives -StorageClass STANDARD_IA C:\Backups\photos.zip
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Archive,

    [Alias('b')]
    [string]$Bucket,

    [Alias('Profile', 'p')]
    [string]$AwsProfile,

    [string]$Prefix,

    [Alias('s')]
    [string]$StorageClass,

    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:SupportedStorageClasses = @(
    'STANDARD',
    'REDUCED_REDUNDANCY',
    'STANDARD_IA',
    'ONEZONE_IA',
    'INTELLIGENT_TIERING',
    'GLACIER',
    'DEEP_ARCHIVE',
    'GLACIER_IR'
)

function Show-Usage {
    @'
Usage: upload-to-s3.ps1 [options] -Archive <compressed-file>

Upload a compressed file to Amazon S3.

Options:
  -Bucket NAME          Destination S3 bucket (or S3_BUCKET).
  -Profile NAME         AWS CLI profile (default: default).
  -Prefix PATH          Destination prefix (default: backups).
  -StorageClass CLASS   S3 storage class (default: STANDARD).
  -Archive FILE         Compressed file to upload.
  -Help                 Show this help message.

Supported formats:
  .zip, .tar.gz, .tgz, .tar.bz2, .tar.xz
'@
}

function Resolve-Setting {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$EnvironmentName,

        [AllowNull()]
        [string]$DefaultValue
    )

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return $Value
    }

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName)
    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        return $environmentValue
    }

    return $DefaultValue
}

function Test-AwsSession {
    param(
        [Parameter(Mandatory)]
        [string]$ProfileName
    )

    & aws sts get-caller-identity --profile $ProfileName *> $null
    return ($LASTEXITCODE -eq 0)
}

function Get-S3Destination {
    param(
        [Parameter(Mandatory)]
        [string]$BucketName,

        [AllowEmptyString()]
        [string]$PrefixPath,

        [Parameter(Mandatory)]
        [string]$ArchivePath
    )

    $fileName = [IO.Path]::GetFileName($ArchivePath)
    $normalizedPrefix = $PrefixPath.Trim([char[]]@('/'))

    if ([string]::IsNullOrWhiteSpace($normalizedPrefix)) {
        return "s3://${BucketName}/${fileName}"
    }

    return "s3://${BucketName}/${normalizedPrefix}/${fileName}"
}

function Invoke-Upload {
    param(
        [AllowNull()]
        [string]$ArchivePath,

        [AllowNull()]
        [string]$BucketName,

        [AllowNull()]
        [string]$ProfileName,

        [AllowNull()]
        [string]$PrefixPath,

        [AllowNull()]
        [string]$SelectedStorageClass
    )

    $resolvedBucket = Resolve-Setting -Value $BucketName -EnvironmentName 'S3_BUCKET'
    $resolvedProfile = Resolve-Setting -Value $ProfileName -EnvironmentName 'AWS_PROFILE' -DefaultValue 'default'
    $resolvedPrefix = Resolve-Setting -Value $PrefixPath -EnvironmentName 'S3_PREFIX' -DefaultValue 'backups'
    $resolvedStorageClass = Resolve-Setting -Value $SelectedStorageClass -EnvironmentName 'S3_STORAGE_CLASS' -DefaultValue 'STANDARD'

    if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
        throw 'Exactly one compressed file is required. Use -Archive or provide it as the first positional argument.'
    }

    if ([string]::IsNullOrWhiteSpace($resolvedBucket)) {
        throw 'S3 bucket is required. Use -Bucket or S3_BUCKET.'
    }

    if ($script:SupportedStorageClasses -cnotcontains $resolvedStorageClass) {
        throw "Unsupported S3 storage class: ${resolvedStorageClass}."
    }

    if (-not [IO.File]::Exists($ArchivePath)) {
        throw "File not found: ${ArchivePath}"
    }

    if ($ArchivePath -cnotmatch '\.(zip|tar\.gz|tgz|tar\.bz2|tar\.xz)$') {
        throw 'Unsupported compressed file format.'
    }

    if ($null -eq (Get-Command -Name 'aws' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)) {
        throw 'AWS CLI is not installed or is not in PATH.'
    }

    Write-Output "Checking AWS session for profile ${resolvedProfile}..."

    if (-not (Test-AwsSession -ProfileName $resolvedProfile)) {
        Write-Output 'AWS session is unavailable or expired. Starting SSO login...'
        & aws sso login --profile $resolvedProfile

        if ($LASTEXITCODE -ne 0) {
            throw "AWS SSO login failed with exit code ${LASTEXITCODE}."
        }

        if (-not (Test-AwsSession -ProfileName $resolvedProfile)) {
            throw 'AWS identity could not be verified after SSO login.'
        }
    }

    $destination = Get-S3Destination `
        -BucketName $resolvedBucket `
        -PrefixPath $resolvedPrefix `
        -ArchivePath $ArchivePath

    Write-Output "Uploading: ${ArchivePath}"
    Write-Output "Destination: ${destination}"
    Write-Output "Storage class: ${resolvedStorageClass}"

    & aws s3 cp $ArchivePath $destination `
        --storage-class $resolvedStorageClass `
        --profile $resolvedProfile

    if ($LASTEXITCODE -ne 0) {
        throw "Upload failed with exit code ${LASTEXITCODE}."
    }

    Write-Output 'Upload completed successfully.'
}

if ($Help) {
    Show-Usage
    exit 0
}

try {
    Invoke-Upload `
        -ArchivePath $Archive `
        -BucketName $Bucket `
        -ProfileName $AwsProfile `
        -PrefixPath $Prefix `
        -SelectedStorageClass $StorageClass
}
catch {
    [Console]::Error.WriteLine('Error: {0}', $_.Exception.Message)
    exit 1
}
