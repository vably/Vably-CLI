# Vably CLI

Use the `vably` command to work with Vably wallets, Devnet tokens, transactions, and programs from a terminal. This standalone bundle installs the Vably command wrapper and the Agave CLI tools it uses underneath.

The installer is per-user and does not need administrator access. It downloads the pinned Agave v4.3.2 release from Anza and verifies the archive's SHA-256 checksum before installing it. It does not replace the existing `solana` command or change CLI settings by itself.

## Supported systems

- Windows x64 (PowerShell and Command Prompt)
- macOS x64 (Intel) and arm64 (Apple Silicon)
- Linux x64 with glibc

The pinned Agave release does not provide a prebuilt Linux arm64 package. Other architectures and Linux distributions without glibc are not supported by these installers. On Windows, the native CLI can deploy a prebuilt program; use WSL to build Rust programs.

## 1. Get the files

Download the repository ZIP from GitHub and extract it, or clone it with Git:

```sh
git clone https://github.com/vably/vably-cli.git
cd vably-cli
```

If you downloaded a ZIP, open a terminal in the extracted `vably-cli` directory instead. Keep the installer and its matching wrapper together.

You need an internet connection to download Agave from GitHub. On macOS and Linux, the installer also needs `curl`, `tar` with bzip2 support, and either `shasum` or `sha256sum`. Windows needs PowerShell, `tar.exe`, and a current 64-bit Windows installation.

## 2. Install

Choose the command for your system and run it from the `vably-cli` folder.

### macOS or Linux

```sh
bash ./install.sh
```

### Windows PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

The installer downloads and verifies Agave v4.3.2, puts the engine and `vably` wrapper in your user account, and adds the wrapper directory to your user PATH. It does not need administrator privileges. Open a new terminal after installation.

Confirm the installation:

```sh
vably --version
vably help
```

The version output shows both the Vably wrapper and Agave engine versions.

## 3. Create or choose a wallet

Create a new wallet locally:

```sh
vably keygen new
vably address
```

`keygen new` asks Agave to create a keypair and recovery phrase. Store the recovery phrase and keypair file securely. Never share either one, commit them to a repository, or paste them into a website or chat. Creating a wallet does not request tokens or submit a transaction.

To use an existing keypair file, pass `--keypair <PATH>` to the command that needs it, for example:

```sh
vably balance <WALLET_ADDRESS> --keypair <PATH_TO_KEYPAIR>
```

## 4. Try Vably Devnet

Network commands use Vably Devnet by default. Request test tokens for your wallet, then check its balance.

### macOS or Linux

```sh
WALLET_ADDRESS="$(vably address)"
vably airdrop 5 "$WALLET_ADDRESS"
vably balance "$WALLET_ADDRESS"
```

### Windows PowerShell

```powershell
$walletAddress = vably address
vably airdrop 5 $walletAddress
vably balance $walletAddress
```

Devnet tokens are for testing and have no real-world value. The public faucet applies rate limits. Balance output may use the label `SOL`, which comes from the underlying Agave CLI; on Vably it represents Vably's native token.

## 5. Use the CLI

The wrapper passes Agave CLI commands through, so use `vably` in place of `solana` for network commands.

```sh
vably address
vably balance <WALLET_ADDRESS>
vably airdrop 5 <WALLET_ADDRESS>                 # Devnet only
vably transfer <RECIPIENT_ADDRESS> 0.1
vably program deploy <PROGRAM.so>
```

Useful references:

```sh
vably help
vably --version
```

### Select a network

Devnet is the default. Select another built-in Vably network with `--url`:

```sh
vably balance <WALLET_ADDRESS> --url devnet
vably balance <WALLET_ADDRESS> --url mainnet
vably balance <WALLET_ADDRESS> --url localnet
```

- `devnet` maps to `https://devnet.vably.network`.
- `mainnet` maps to `https://mainnet.vably.network`. You must type `--url mainnet` explicitly; Mainnet has no faucet and transactions require a funded wallet.
- `localnet` maps to `http://127.0.0.1:12899`. A local Vably node or the required tunnel must already be running.

For a program deployment, add `--url mainnet` only when you intend to deploy to Vably Mainnet:

```sh
vably program deploy <PROGRAM.so> --url mainnet
```

The wrapper rejects the Solana network aliases `mainnet-beta` and `testnet`, and rejects URLs containing `solana.com`. Other custom URLs are forwarded unchanged, so check any custom endpoint carefully before signing or sending a transaction. The `vably config` command is also passed through as typed and can change the Agave CLI configuration shared with other Agave/Solana CLI commands.

## 6. Deploy a program

The installer prepares the CLI; it does not compile a program, create or fund a wallet, or submit a deployment for you. You need a compiled `.so` program file and a wallet with enough VAB on the selected network for deployment costs.

For a Rust program, install Rust/Cargo and the Agave program build tools using the [official Anza CLI guide](https://docs.anza.xyz/cli/install), then build and deploy:

```sh
cargo build-sbf
vably program deploy target/deploy/<PROGRAM_NAME>.so
```

This deploys to Devnet by default. To deploy to Mainnet, specify it explicitly:

```sh
vably program deploy target/deploy/<PROGRAM_NAME>.so --url mainnet
```

Review the selected network, program file, wallet, and deployment cost before confirming a deployment. Windows users should build in WSL and can use the native Windows CLI to deploy a prebuilt `.so` file.

## Install locations and advanced options

By default, the installer keeps Vably's Agave engine separate from other CLI installations:

- macOS/Linux engine: `~/.local/share/vably-cli/agave/v4.3.2`
- macOS/Linux command: `~/.local/bin/vably`
- Windows engine and command: `%LOCALAPPDATA%\Vably`

The installers append their command directory to your user PATH. On macOS/Linux, they add a marked PATH block to the shell startup file for the current shell. On Windows, the wrapper is available from both PowerShell and Command Prompt.

Optional environment variables:

- `VABLY_DATA_HOME` changes the Vably CLI data/install directory.
- `XDG_DATA_HOME` supplies the base data directory when `VABLY_DATA_HOME` is not set.
- `VABLY_BIN_DIR` changes the installed command directory on macOS/Linux.
- `VABLY_AGAVE_BIN` tells the wrapper to use an existing directory containing the Agave executables.

The release version and checksums are pinned in the installer. To update, download the newer Vably CLI bundle when one is published and run its installer. The installer does not automatically update itself.

## Troubleshooting

- **`vably` is not recognized:** Open a new terminal after installation. If it still fails, check that the user PATH contains `~/.local/bin` on macOS/Linux or `%LOCALAPPDATA%\Vably\bin` on Windows.
- **The Agave archive fails checksum verification:** Stop and try again later. Do not bypass the checksum check; report the issue with the Agave version and your operating system.
- **Installer says the Agave folder is incomplete:** Move or rename only the Vably-managed `agave/v4.3.2` folder (macOS/Linux) or `Agave/v4.3.2` folder (Windows), then run the installer again. Do not remove your wallet/keypair files.
- **Linux ARM or another unsupported system:** The pinned release has no matching prebuilt package. The installer stops rather than installing a binary for the wrong architecture.
- **Deployment fails for lack of funds:** Confirm the network with `--url`, then make sure the wallet has enough tokens on that same network. Devnet tokens cannot be used on Mainnet.

## Files in this repository

- `install.sh` — macOS/Linux per-user installer
- `install.ps1` — Windows x64 per-user installer
- `vably.sh` — macOS/Linux command wrapper
- `vably.ps1` — PowerShell command wrapper
- `vably.cmd` — Command Prompt entry point for Windows

## License

This project is licensed under the Apache License 2.0. See [`LICENSE`](LICENSE) for the full terms. The Agave CLI binaries are third-party software distributed by Anza under their own license and release terms.
