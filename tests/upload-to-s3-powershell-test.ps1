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

    if ($env:OS -eq 'Windows_NT') {
        $mockAws = @'
@echo off
echo %*>>"%MOCK_LOG%"

if "%1"=="sts" if "%2"=="get-caller-identity" (
    if "%MOCK_IDENTITY_FAIL_ONCE%"=="1" if not exist "%MOCK_STATE_DIR%\identity-failed" (
        type nul >"%MOCK_STATE_DIR%\identity-failed"
        exit /b 1
    )
    exit /b 0
)

if "%1"=="sso" if "%2"=="login" exit /b 0
if "%1"=="s3" if "%2"=="cp" exit /b 0

exit /b 1
'@

        Set-Content -LiteralPath (Join-Path $mockBinDirectory 'aws.cmd') -Value $mockAws -Encoding Ascii
    }
    else {
        $mockAws = @'
#!/usr/bin/env bash

set -eu

printf '%s\n' "$*" >>"${MOCK_LOG:?}"

if [[ "${1:-}" == "sts" && "${2:-}" == "get-caller-identity" ]]; then
    if [[ "${MOCK_IDENTITY_FAIL_ONCE:-0}" == "1" && ! -f "${MOCK_STATE_DIR:?}/identity-failed" ]]; then
        touch "${MOCK_STATE_DIR}/identity-failed"
        exit 1
    fi

    exit 0
fi

if [[ "${1:-}" == "sso" && "${2:-}" == "login" ]]; then
    exit 0
fi

if [[ "${1:-}" == "s3" && "${2:-}" == "cp" ]]; then
    exit 0
fi

exit 1
'@

        $mockAwsPath = Join-Path $mockBinDirectory 'aws'
        Set-Content -LiteralPath $mockAwsPath -Value $mockAws -Encoding Ascii
        & chmod +x $mockAwsPath

        if ($LASTEXITCODE -ne 0) {
            throw 'Could not make the mocked AWS CLI executable.'
        }
    }

    $env:PATH = "${mockBinDirectory}$([IO.Path]::PathSeparator)$($env:PATH)"
    $env:MOCK_LOG = $mockLog
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
