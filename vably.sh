#!/usr/bin/env bash
# Vably CLI wrapper. Agave supplies the compatible command-line engine.
set -euo pipefail

VABLY_VERSION="1.0.0"
AGAVE_VERSION="4.3.2"
VABLY_DEVNET_URL="https://devnet.vably.network"
VABLY_MAINNET_URL="https://mainnet.vably.network"
VABLY_LOCALNET_URL="http://127.0.0.1:12899"
DATA_HOME="${VABLY_DATA_HOME:-${XDG_DATA_HOME:-"${HOME:?HOME must be set}/.local/share"}/vably-cli}"
ENGINE_BIN="${VABLY_AGAVE_BIN:-${DATA_HOME}/agave/v${AGAVE_VERSION}/bin}"
SOLANA="${ENGINE_BIN}/solana"
SOLANA_KEYGEN="${ENGINE_BIN}/solana-keygen"

usage() {
  cat <<'USAGE'
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
USAGE
}

fail() {
  printf 'vably: %s\n' "$1" >&2
  exit "${2:-2}"
}

need_engine() {
  local tool="$1"
  [[ -x "$tool" ]] || fail 'the Vably-managed Agave tools are missing. Run the Vably CLI installer again.' 127
}

resolve_url() {
  case "$1" in
    devnet|d) printf '%s' "$VABLY_DEVNET_URL" ;;
    localnet|localhost|l) printf '%s' "$VABLY_LOCALNET_URL" ;;
    mainnet) printf '%s' "$VABLY_MAINNET_URL" ;;
    mainnet-beta) fail 'mainnet-beta is the name Solana uses for its own mainnet. For Vably Mainnet use --url mainnet.' ;;
    m) fail 'type --url mainnet in full to use Vably Mainnet.' ;;
    testnet|t) fail 'Vably has no testnet. Use --url devnet or --url localnet.' ;;
    *solana.com*) fail 'that is a Solana endpoint. vably only talks to Vably networks.' ;;
    *) printf '%s' "$1" ;;
  esac
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

case "$1" in
  help|-h|--help)
    usage
    exit 0
    ;;
  version|-V|--version)
    need_engine "$SOLANA"
    printf 'vably %s, using Agave %s\n' "$VABLY_VERSION" "$AGAVE_VERSION"
    exec "$SOLANA" --version
    ;;
  keygen)
    shift
    need_engine "$SOLANA_KEYGEN"
    exec "$SOLANA_KEYGEN" "$@"
    ;;
esac

need_engine "$SOLANA"
args=()
has_url=0
target=""
command_word=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      args+=("$@")
      break
      ;;
    --url|-u)
      [[ $# -ge 2 ]] || fail "$1 needs a value, like --url devnet."
      url="$(resolve_url "$2")" || exit $?
      args+=("$1" "$url")
      has_url=1
      target="$url"
      shift 2
      ;;
    --url=*)
      url="$(resolve_url "${1#--url=}")" || exit $?
      args+=("--url=$url")
      has_url=1
      target="$url"
      shift
      ;;
    *)
      if [[ -z "$command_word" && "$1" != -* ]]; then command_word="$1"; fi
      args+=("$1")
      shift
      ;;
  esac
done

if [[ "$command_word" == "airdrop" && "$target" == "$VABLY_MAINNET_URL" ]]; then
  fail 'Vably Mainnet has no faucet. Use --url devnet to request test tokens.'
fi

if (( has_url == 0 )) && [[ "${args[0]}" != "config" ]]; then
  exec "$SOLANA" --url "$VABLY_DEVNET_URL" "${args[@]}"
fi
exec "$SOLANA" "${args[@]}"

