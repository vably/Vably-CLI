#!/usr/bin/env bash
set -euo pipefail

VABLY_VERSION="1.0.0"
AGAVE_VERSION="4.3.2"
RELEASE_TAG="v${AGAVE_VERSION}"
RELEASE_BASE="https://github.com/anza-xyz/agave/releases/download/${RELEASE_TAG}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${VABLY_DATA_HOME:-${XDG_DATA_HOME:-"${HOME:?HOME must be set}/.local/share"}/vably-cli}"
BIN_DIR="${VABLY_BIN_DIR:-${HOME:?HOME must be set}/.local/bin}"
ENGINE_DIR="${DATA_HOME}/agave/${RELEASE_TAG}"

fail() {
  printf 'vably installer: %s\n' "$1" >&2
  exit "${2:-1}"
}

case "$(uname -s):$(uname -m)" in
  Darwin:arm64|Darwin:aarch64)
    ASSET="solana-release-aarch64-apple-darwin.tar.bz2"
    SHA256="5439bd2a42c9e8b39923377361a14c9267f6ce699308f9255fb71c3017af76fd"
    ;;
  Darwin:x86_64)
    ASSET="solana-release-x86_64-apple-darwin.tar.bz2"
    SHA256="0b814d10d774ea3c0211edd51420444e9aadf8b9d08d35d9417d0bcb74e7a5e4"
    ;;
  Linux:x86_64)
    ASSET="solana-release-x86_64-unknown-linux-gnu.tar.bz2"
    SHA256="5c9599d7fa397375df69d58e8d4f550ee45463dd6d1ecad9e5a1f053ce8e0933"
    ;;
  *)
    fail "Agave ${AGAVE_VERSION} has no supported prebuilt package for $(uname -s) $(uname -m). Supported targets: macOS x64/arm64 and Linux x64."
    ;;
esac

[[ -f "${SCRIPT_DIR}/vably.sh" ]] || fail "vably.sh must be alongside this installer. Download or clone the complete Vably CLI folder."
command -v curl >/dev/null 2>&1 || fail 'curl is required.'
command -v tar >/dev/null 2>&1 || fail 'tar is required.'
if command -v shasum >/dev/null 2>&1; then
  HASH_COMMAND="shasum"
elif command -v sha256sum >/dev/null 2>&1; then
  HASH_COMMAND="sha256sum"
else
  fail 'a SHA-256 utility (shasum or sha256sum) is required.'
fi

if [[ -e "${ENGINE_DIR}" ]]; then
  [[ -x "${ENGINE_DIR}/bin/solana" && -x "${ENGINE_DIR}/bin/solana-keygen" ]] || fail "${ENGINE_DIR} already exists but is not a complete Vably-managed Agave install. Move it aside, then run this installer again."
  ENGINE_VERSION_OUTPUT="$("${ENGINE_DIR}/bin/solana" --version 2>&1 || true)"
  [[ "${ENGINE_VERSION_OUTPUT}" == *"${AGAVE_VERSION}"* ]] || fail "${ENGINE_DIR} exists but does not report Agave ${AGAVE_VERSION}; move it aside before reinstalling."
  printf 'Agave %s is already installed.\n' "${AGAVE_VERSION}"
else
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vably-cli.XXXXXX")"
  trap 'rm -rf "${TMP_DIR}"' EXIT
  ARCHIVE="${TMP_DIR}/${ASSET}"
  printf 'Downloading Agave %s for %s...\n' "${AGAVE_VERSION}" "$(uname -s) $(uname -m)"
  curl --fail --location --silent --show-error "${RELEASE_BASE}/${ASSET}" --output "${ARCHIVE}" || fail 'Agave download failed.'
  if [[ "${HASH_COMMAND}" == "shasum" ]]; then
    printf '%s  %s\n' "${SHA256}" "${ARCHIVE}" | shasum -a 256 -c - >/dev/null || fail 'the downloaded Agave archive failed SHA-256 verification.'
  else
    printf '%s  %s\n' "${SHA256}" "${ARCHIVE}" | sha256sum -c - >/dev/null || fail 'the downloaded Agave archive failed SHA-256 verification.'
  fi
  tar -xjf "${ARCHIVE}" -C "${TMP_DIR}" || fail 'could not unpack the Agave archive; make sure tar supports bzip2.'
  RELEASE_BIN="${TMP_DIR}/solana-release/bin"
  [[ -x "${RELEASE_BIN}/solana" && -x "${RELEASE_BIN}/solana-keygen" ]] || fail 'the Agave archive did not contain the expected CLI tools.'
  ENGINE_PARENT="$(dirname "${ENGINE_DIR}")"
  mkdir -p "${ENGINE_PARENT}"
  STAGE_DIR="$(mktemp -d "${ENGINE_PARENT}/.${RELEASE_TAG}.XXXXXX")"
  mkdir -p "${STAGE_DIR}/bin"
  cp -R "${RELEASE_BIN}/." "${STAGE_DIR}/bin/"
  STAGED_VERSION_OUTPUT="$("${STAGE_DIR}/bin/solana" --version 2>&1 || true)"
  [[ "${STAGED_VERSION_OUTPUT}" == *"${AGAVE_VERSION}"* ]] || fail "the downloaded CLI does not report Agave ${AGAVE_VERSION}."
  mv "${STAGE_DIR}" "${ENGINE_DIR}"
  printf 'Installed Agave %s.\n' "${AGAVE_VERSION}"
fi

mkdir -p "${BIN_DIR}"
install -m 755 "${SCRIPT_DIR}/vably.sh" "${BIN_DIR}/vably"

add_path_block() {
  local profile="$1"
  if ! grep -Fq '# >>> vably-cli PATH >>>' "${profile}" 2>/dev/null; then
    {
      printf '\n# >>> vably-cli PATH >>>\n'
      printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "${BIN_DIR}" "${BIN_DIR}"
      printf '# <<< vably-cli PATH <<<\n'
    } >> "${profile}"
  fi
}

SHELL_NAME="$(basename "${SHELL:-sh}")"
case "${SHELL_NAME}" in
  zsh)
    add_path_block "${HOME}/.zshrc"
    add_path_block "${HOME}/.zprofile"
    ;;
  bash)
    add_path_block "${HOME}/.bashrc"
    if [[ -f "${HOME}/.bash_profile" ]]; then
      add_path_block "${HOME}/.bash_profile"
    elif [[ -f "${HOME}/.bash_login" ]]; then
      add_path_block "${HOME}/.bash_login"
    else
      add_path_block "${HOME}/.profile"
    fi
    ;;
  *)
    add_path_block "${HOME}/.profile"
    ;;
esac

export PATH="${BIN_DIR}:${PATH}"
printf '\nVably CLI %s is installed.\n' "${VABLY_VERSION}"
printf 'Run: vably --version\n'
printf 'Default network: Vably Devnet. Mainnet requires --url mainnet.\n'
printf 'Open a new terminal to use vably from your PATH.\n'

