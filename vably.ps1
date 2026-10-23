# Vably CLI wrapper for Windows PowerShell.
$VablyVersion = '1.0.0'
$AgaveVersion = '4.3.2'
$DevnetUrl = 'https://devnet.vably.network'
$MainnetUrl = 'https://mainnet.vably.network'
$LocalnetUrl = 'http://127.0.0.1:12899'

if ($env:VABLY_DATA_HOME) {
  $dataHome = $env:VABLY_DATA_HOME
}
elseif ($env:XDG_DATA_HOME) {
  $dataHome = Join-Path $env:XDG_DATA_HOME 'vably-cli'
}
else {
  $dataHome = Join-Path $env:LOCALAPPDATA 'Vably'
}
$engineBin = if ($env:VABLY_AGAVE_BIN) { $env:VABLY_AGAVE_BIN } else { Join-Path $dataHome "Agave\v$AgaveVersion\bin" }
$solana = Join-Path $engineBin 'solana.exe'
$keygen = Join-Path $engineBin 'solana-keygen.exe'

$Usage = @'
vably: use Vably from your terminal.

Usage: vably <command> [arguments] [--url devnet|mainnet|localnet|URL]

Every command talks to Vably Devnet unless you pick another Vably
network with --url. Mainnet only runs when you type --url mainnet.

  vably keygen new                    Create a wallet keypair
  vably address                       Show your wallet address
  vably airdrop 5 <WALLET_ADDRESS>    Request Vably Devnet tokens
  vably balance <WALLET_ADDRESS>      Check a balance
  vably transfer <TO> <AMOUNT>        Send tokens
  vably program deploy <FILE.so>      Deploy a program
  vably --version                     Show versions

Networks: devnet (default), mainnet and localnet. Mainnet has no faucet.
'@

function Stop-Vably([string]$Message, [int]$Code = 2) {
  [Console]::Error.WriteLine("vably: $Message")
  exit $Code
}

function Resolve-VablyUrl([string]$Value) {
  switch -Regex ($Value) {
    '^(devnet|d)$' { return $DevnetUrl }
    '^(localnet|localhost|l)$' { return $LocalnetUrl }
    '^mainnet$' { return $MainnetUrl }
    '^mainnet-beta$' { Stop-Vably 'mainnet-beta is the name Solana uses for its own mainnet. For Vably Mainnet use --url mainnet.' }
    '^m$' { Stop-Vably 'type --url mainnet in full to use Vably Mainnet.' }
    '^(testnet|t)$' { Stop-Vably 'Vably has no testnet. Use --url devnet or --url localnet.' }
    'solana\.com' { Stop-Vably 'that is a Solana endpoint. vably only talks to Vably networks.' }
  }
  return $Value
}

if ($args.Count -eq 0) {
  [Console]::Error.WriteLine($Usage)
  exit 2
}

$first = [string]$args[0]
if ($first -in @('help', '-h', '--help')) {
  [Console]::Out.WriteLine($Usage)
  exit 0
}
if ($first -in @('version', '-V', '--version')) {
  if (-not (Test-Path -LiteralPath $solana)) { Stop-Vably 'the Vably-managed Agave tools are missing. Run the Vably CLI installer again.' 127 }
  [Console]::Out.WriteLine("vably $VablyVersion, using Agave $AgaveVersion")
  & $solana --version
  exit $LASTEXITCODE
}
if ($first -eq 'keygen') {
  if (-not (Test-Path -LiteralPath $keygen)) { Stop-Vably 'the Vably-managed Agave tools are missing. Run the Vably CLI installer again.' 127 }
  $rest = @($args | Select-Object -Skip 1)
  & $keygen @rest
  exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $solana)) { Stop-Vably 'the Vably-managed Agave tools are missing. Run the Vably CLI installer again.' 127 }
$forward = New-Object System.Collections.Generic.List[string]
$hasUrl = $false
$target = ''
$commandWord = ''
for ($i = 0; $i -lt $args.Count; $i++) {
  $arg = [string]$args[$i]
  if ($arg -eq '--') {
    for ($j = $i; $j -lt $args.Count; $j++) { $forward.Add([string]$args[$j]) }
    break
  }
  if ($arg -eq '--url' -or $arg -eq '-u') {
    if ($i + 1 -ge $args.Count) { Stop-Vably "$arg needs a value, like --url devnet." }
    $target = Resolve-VablyUrl ([string]$args[$i + 1])
    $forward.Add($arg)
    $forward.Add($target)
    $hasUrl = $true
    $i++
    continue
  }
  if ($arg -like '--url=*') {
    $target = Resolve-VablyUrl $arg.Substring(6)
    $forward.Add('--url=' + $target)
    $hasUrl = $true
    continue
  }
  if ($commandWord -eq '' -and -not $arg.StartsWith('-')) { $commandWord = $arg }
  $forward.Add($arg)
}

if ($commandWord -eq 'airdrop' -and $target -eq $MainnetUrl) {
  Stop-Vably 'Vably Mainnet has no faucet. Use --url devnet to request test tokens.'
}
if (-not $hasUrl -and $first -ne 'config') {
  $forward.Insert(0, $DevnetUrl)
  $forward.Insert(0, '--url')
}

$argv = $forward.ToArray()
& $solana @argv
exit $LASTEXITCODE

