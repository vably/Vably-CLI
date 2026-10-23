$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$VablyVersion = '1.0.0'
$AgaveVersion = '4.3.2'
$ReleaseTag = "v$AgaveVersion"
$ReleaseBase = "https://github.com/anza-xyz/agave/releases/download/$ReleaseTag"
$Asset = 'solana-release-x86_64-pc-windows-msvc.tar.bz2'
$ExpectedSha256 = 'ce29128589045fe1964e9d5c064ea5f2a58151f707bae4d5bab345a3725e0f09'
$InstallRoot = if ($env:VABLY_DATA_HOME) { $env:VABLY_DATA_HOME } elseif ($env:XDG_DATA_HOME) { Join-Path $env:XDG_DATA_HOME 'vably-cli' } else { Join-Path $env:LOCALAPPDATA 'Vably' }
$AgaveRoot = Join-Path $InstallRoot 'Agave'
$EngineHome = Join-Path $AgaveRoot $ReleaseTag
$EngineDir = Join-Path $EngineHome 'bin'
$BinDir = Join-Path $InstallRoot 'bin'

if ($PSVersionTable.PSVersion.Major -lt 7) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Stop-VablyInstall([string]$Message) {
  [Console]::Error.WriteLine("vably installer: $Message")
  exit 1
}

if (-not [Environment]::Is64BitOperatingSystem) {
  Stop-VablyInstall 'the native Windows installer supports x64 Windows only.'
}
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'vably.ps1'))) {
  Stop-VablyInstall 'vably.ps1 must be alongside this installer. Download or clone the complete Vably CLI folder.'
}
if (-not (Get-Command tar.exe -ErrorAction SilentlyContinue)) {
  Stop-VablyInstall 'Windows tar.exe is required. Use a current Windows 10/11 installation or install a bzip2-capable tar utility.'
}

$alreadyInstalled = $false
$solanaExe = Join-Path $EngineDir 'solana.exe'
if (Test-Path -LiteralPath $EngineHome) {
  if (-not (Test-Path -LiteralPath $solanaExe) -or -not (Test-Path -LiteralPath (Join-Path $EngineDir 'solana-keygen.exe'))) {
    Stop-VablyInstall "$EngineHome already exists but is not a complete Vably-managed Agave install. Move it aside, then run this installer again."
  }
  $installedVersion = (& $solanaExe --version 2>&1 | Out-String)
  if ($installedVersion -notmatch [regex]::Escape($AgaveVersion)) {
    Stop-VablyInstall "$EngineHome exists but does not report Agave $AgaveVersion; move it aside before reinstalling."
  }
  $alreadyInstalled = $true
  Write-Host "Agave $AgaveVersion is already installed."
}

if (-not $alreadyInstalled) {
  $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("vably-cli-" + [guid]::NewGuid().ToString('N'))
  $stageHome = $null
  New-Item -ItemType Directory -Path $tempDir | Out-Null
  try {
    $archive = Join-Path $tempDir $Asset
    Write-Host "Downloading Agave $AgaveVersion for Windows x64..."
    Invoke-WebRequest -Uri "$ReleaseBase/$Asset" -OutFile $archive
    $actualSha256 = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSha256 -ne $ExpectedSha256) {
      Stop-VablyInstall 'the downloaded Agave archive failed SHA-256 verification.'
    }

    & tar.exe -xjf $archive -C $tempDir
    if ($LASTEXITCODE -ne 0) { Stop-VablyInstall 'could not unpack the Agave archive.' }
    $releaseBin = Join-Path $tempDir 'solana-release\bin'
    foreach ($tool in @('solana.exe', 'solana-keygen.exe')) {
      if (-not (Test-Path -LiteralPath (Join-Path $releaseBin $tool))) {
        Stop-VablyInstall "the Agave archive did not contain $tool."
      }
    }

    New-Item -ItemType Directory -Force -Path $AgaveRoot | Out-Null
    $stageHome = Join-Path $AgaveRoot (".$ReleaseTag-" + [guid]::NewGuid().ToString('N'))
    $stageBin = Join-Path $stageHome 'bin'
    New-Item -ItemType Directory -Path $stageBin | Out-Null
    Copy-Item -Path (Join-Path $releaseBin '*') -Destination $stageBin -Recurse -Force
    $stagedVersion = (& (Join-Path $stageBin 'solana.exe') --version 2>&1 | Out-String)
    if ($stagedVersion -notmatch [regex]::Escape($AgaveVersion)) {
      Stop-VablyInstall "the downloaded CLI does not report Agave $AgaveVersion."
    }
    Move-Item -LiteralPath $stageHome -Destination $EngineHome
    Write-Host "Installed Agave $AgaveVersion."
  }
  finally {
    if ($stageHome -and (Test-Path -LiteralPath $stageHome)) {
      Remove-Item -LiteralPath $stageHome -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'vably.ps1') -Destination (Join-Path $BinDir 'vably.ps1') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'vably.cmd') -Destination (Join-Path $BinDir 'vably.cmd') -Force

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathParts = @($userPath -split ';' | Where-Object { $_ -and $_.Trim() })
if (-not ($pathParts | Where-Object { $_.TrimEnd('\') -ieq $BinDir.TrimEnd('\') })) {
  $pathParts += $BinDir
  [Environment]::SetEnvironmentVariable('Path', ($pathParts -join ';'), 'User')
}
$env:Path = "$BinDir;$env:Path"

Write-Host "`nVably CLI $VablyVersion is installed."
Write-Host 'Run: vably --version'
Write-Host 'Default network: Vably Devnet. Mainnet requires --url mainnet.'
Write-Host 'Open a new terminal to use vably from your PATH.'

