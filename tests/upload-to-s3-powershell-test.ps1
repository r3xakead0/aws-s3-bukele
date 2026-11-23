#requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptUnderTest = Join-Path $projectRoot 'bin/upload-to-s3.ps1'
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) "aws-s3-bukele-$([guid]::NewGuid().ToString('N'))"
$mockBinDirectory = Join-Path $testDirectory 'bin'
$mockStateDirectory = Join-Path $testDirectory 'state'
$mockLog = Join-Path $testDirectory 'aws.log'
$archive = Join-Path $testDirectory 'archive.zip'
$archiveWithSpaces = Join-Path $testDirectory 'my archive.zip'
$unsupportedFile = Join-Path $testDirectory 'notes.txt'
$powerShellExecutable = (Get-Process -Id $PID).Path
$testsRun = 0
$commandOutput = ''
$commandStatus = 0

$environmentNames = @(
    'PATH',
    'MOCK_LOG',
    'MOCK_PWSH_PATH',
    'MOCK_STATE_DIR',
    'MOCK_IDENTITY_FAIL_ONCE',
    'S3_BUCKET',
    'AWS_PROFILE',
    'S3_PREFIX',
    'S3_STORAGE_CLASS'
)

$originalEnvironment = @{}
foreach ($environmentName in $environmentNames) {
    $originalEnvironment[$environmentName] = [Environment]::GetEnvironmentVariable($environmentName, 'Process')
}

function Invoke-TestCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $script:commandOutput = (& $powerShellExecutable `
        -NoLogo `
        -NoProfile `
        -NonInteractive `
        -ExecutionPolicy Bypass `
        -File $scriptUnderTest `
        @Arguments 2>&1 | Out-String)
    $script:commandStatus = $LASTEXITCODE
    $script:testsRun++
}

function Assert-Status {
    param(
        [Parameter(Mandatory)]
        [int]$Expected
    )

    if ($commandStatus -ne $Expected) {
        throw "Expected status ${Expected}, got ${commandStatus}. Output: $commandOutput"
    }
}

function Assert-OutputContains {
    param(
        [Parameter(Mandatory)]
        [string]$Expected
    )

    if (-not $commandOutput.Contains($Expected)) {
        throw "Output does not contain '${Expected}'. Output: $commandOutput"
    }
}

function Assert-LogContains {
    param(
        [Parameter(Mandatory)]
        [string]$Expected
    )

    $logLines = Get-Content -LiteralPath $mockLog
    if ($logLines -cnotcontains $Expected) {
        throw "AWS log does not contain '${Expected}'. Log: $($logLines -join [Environment]::NewLine)"
    }
}

try {
    New-Item -ItemType Directory -Path $mockBinDirectory, $mockStateDirectory -Force | Out-Null
    New-Item -ItemType File -Path $archive, $archiveWithSpaces, $unsupportedFile, $mockLog -Force | Out-Null

    $mockAwsPowerShell = @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AwsArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Content -LiteralPath $env:MOCK_LOG -Value ($AwsArguments -join ' ')

if (
    $AwsArguments.Count -ge 2 -and
    $AwsArguments[0] -ceq 'sts' -and
    $AwsArguments[1] -ceq 'get-caller-identity'
) {
    $failureMarker = Join-Path $env:MOCK_STATE_DIR 'identity-failed'
    if ($env:MOCK_IDENTITY_FAIL_ONCE -eq '1' -and -not (Test-Path -LiteralPath $failureMarker)) {
        New-Item -ItemType File -Path $failureMarker -Force | Out-Null
        exit 1
    }

    exit 0
}

if ($AwsArguments.Count -ge 2 -and $AwsArguments[0] -ceq 'sso' -and $AwsArguments[1] -ceq 'login') {
    exit 0
}

if ($AwsArguments.Count -ge 2 -and $AwsArguments[0] -ceq 's3' -and $AwsArguments[1] -ceq 'cp') {
    exit 0
}

exit 1
'@

    Set-Content `
        -LiteralPath (Join-Path $mockBinDirectory 'aws-mock.ps1') `
        -Value $mockAwsPowerShell `
        -Encoding Ascii

    if ($env:OS -eq 'Windows_NT') {
        $mockAwsWrapper = @'
@echo off
"%MOCK_PWSH_PATH%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0aws-mock.ps1" %*
exit /b %ERRORLEVEL%
'@

        Set-Content -LiteralPath (Join-Path $mockBinDirectory 'aws.cmd') -Value $mockAwsWrapper -Encoding Ascii
    }
    else {
        $mockAwsWrapper = @'
#!/usr/bin/env bash

set -eu

exec "${MOCK_PWSH_PATH:?}" \
    -NoLogo \
    -NoProfile \
    -NonInteractive \
    -File "$(dirname "$0")/aws-mock.ps1" \
    "$@"
'@

        $mockAwsPath = Join-Path $mockBinDirectory 'aws'
        Set-Content -LiteralPath $mockAwsPath -Value $mockAwsWrapper -Encoding Ascii
        & chmod +x $mockAwsPath

        if ($LASTEXITCODE -ne 0) {
            throw 'Could not make the mocked AWS CLI executable.'
        }
    }

    $env:PATH = "${mockBinDirectory}$([IO.Path]::PathSeparator)$($env:PATH)"
    $env:MOCK_LOG = $mockLog
    $env:MOCK_PWSH_PATH = $powerShellExecutable
    $env:MOCK_STATE_DIR = $mockStateDirectory

    Invoke-TestCommand -Arguments @('-Help')
    Assert-Status -Expected 0
    Assert-OutputContains -Expected 'Usage: upload-to-s3.ps1'

    $env:S3_BUCKET = 'test-bucket'
    Invoke-TestCommand -Arguments @('-Archive', (Join-Path $testDirectory 'missing.zip'))
    Assert-Status -Expected 1
    Assert-OutputContains -Expected 'File not found'

    Invoke-TestCommand -Arguments @('-Archive', $unsupportedFile)
    Assert-Status -Expected 1
    Assert-OutputContains -Expected 'Unsupported compressed file format'

    $env:S3_BUCKET = $null
    Invoke-TestCommand -Arguments @('-Archive', $archive)
    Assert-Status -Expected 1
    Assert-OutputContains -Expected 'S3 bucket is required'

    $env:S3_BUCKET = 'test-bucket'
    $env:S3_STORAGE_CLASS = 'INVALID_CLASS'
    Invoke-TestCommand -Arguments @('-Archive', $archive)
    Assert-Status -Expected 1
    Assert-OutputContains -Expected 'Unsupported S3 storage class: INVALID_CLASS'

    Clear-Content -LiteralPath $mockLog
    $env:S3_BUCKET = $null
    $env:S3_STORAGE_CLASS = $null
    Invoke-TestCommand -Arguments @(
        '-Bucket', 'test-bucket',
        '-Profile', 'test-profile',
        '-Archive', $archive
    )
    Assert-Status -Expected 0
    Assert-OutputContains -Expected 'Storage class: STANDARD'
    Assert-LogContains -Expected "s3 cp ${archive} s3://test-bucket/backups/archive.zip --storage-class STANDARD --profile test-profile"

    Clear-Content -LiteralPath $mockLog
    Invoke-TestCommand -Arguments @(
        '-Bucket', 'test-bucket',
        '-Profile', 'test-profile',
        '-Prefix', '/releases/',
        '-StorageClass', 'STANDARD_IA',
        '-Archive', $archive
    )
    Assert-Status -Expected 0
    Assert-OutputContains -Expected 's3://test-bucket/releases/archive.zip'
    Assert-OutputContains -Expected 'Storage class: STANDARD_IA'
    Assert-LogContains -Expected "s3 cp ${archive} s3://test-bucket/releases/archive.zip --storage-class STANDARD_IA --profile test-profile"

    Clear-Content -LiteralPath $mockLog
    Invoke-TestCommand -Arguments @(
        '-Bucket', 'test-bucket',
        '-Profile', 'test-profile',
        '-Archive', $archiveWithSpaces
    )
    Assert-Status -Expected 0
    Assert-OutputContains -Expected 's3://test-bucket/backups/my archive.zip'

    Clear-Content -LiteralPath $mockLog
    Remove-Item -LiteralPath (Join-Path $mockStateDirectory 'identity-failed') -Force -ErrorAction SilentlyContinue
    $env:S3_BUCKET = 'test-bucket'
    $env:AWS_PROFILE = 'test-profile'
    $env:S3_PREFIX = 'backups'
    $env:S3_STORAGE_CLASS = 'GLACIER_IR'
    $env:MOCK_IDENTITY_FAIL_ONCE = '1'
    Invoke-TestCommand -Arguments @('-Archive', $archive)
    Assert-Status -Expected 0
    Assert-OutputContains -Expected 'Starting SSO login'
    Assert-OutputContains -Expected 'Storage class: GLACIER_IR'
    Assert-LogContains -Expected 'sso login --profile test-profile'
    Assert-LogContains -Expected "s3 cp ${archive} s3://test-bucket/backups/archive.zip --storage-class GLACIER_IR --profile test-profile"

    Write-Output "PASS: ${testsRun} PowerShell integration tests completed successfully."
}
finally {
    foreach ($environmentName in $environmentNames) {
        [Environment]::SetEnvironmentVariable(
            $environmentName,
            $originalEnvironment[$environmentName],
            'Process'
        )
    }

    Remove-Item -LiteralPath $testDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
