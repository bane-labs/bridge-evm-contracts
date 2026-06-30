# Ops CLI

The ops CLI is the preferred way to inspect configured bridge deployments, local operator accounts, and guarded operational transactions without using Hardhat tasks or `hh vars`.

Run it through npm:

```sh
npm run ops -- help
npm run ops -- <group> --help
```

For local fork smoke testing, see [ops-fork-smoke.md](ops-fork-smoke.md).

Legacy operational scripts under `scripts/` are removed once their workflows are covered by `ops/`. Deployment, registration, funding, wallet, and local test-helper scripts may still live under `scripts/` until those workflows are migrated separately.

Available groups:

- `config` inspects resolved network, deployment, token, and account config.
- `accounts` inspects local account aliases and resolves account addresses.
- `bridge` reads token bridge state and runs guarded bridge operations.
- `message` reads message bridge state and runs guarded message bridge operations.

## Quick Start

Show resolved config:

```sh
npm run ops -- config show --network neox-testnet
```

Check local account setup:

```sh
npm run ops -- accounts check --network neox-testnet
```

Read token bridge state:

```sh
npm run ops -- bridge state --network neox-testnet
```

Read message bridge state:

```sh
npm run ops -- message state --network neox-testnet
```

Dry-run a store-only message send:

```sh
npm run ops -- message send-store-only --network neox-testnet --account personal --message 0x1234 --dry-run true
```

Dry-run a native claim:

```sh
npm run ops -- bridge claim-native --network neox-testnet --account personal --nonce <nonce> --dry-run true
```

## Configuration

Committed config:

- `config/networks/<network>.json` contains RPC and chain metadata.
- `config/deployments/<network>.json` contains deployed contract addresses and token aliases.
- `config/accounts/<network>.example.json` documents the local account format.

Local config:

- `config/deployments/<network>.local.json` can override deployment values locally.
- `config/accounts/<network>.json` contains local account sources and is ignored by git.

Every config file declares its network name. The CLI rejects mismatches, so a mainnet command cannot accidentally load a testnet accounts or deployment file.

Inspect resolved config:

```sh
npm run ops -- config show --network neox-testnet
```

## Accounts

Create a local account config from the example:

```sh
cp config/accounts/neox-testnet.example.json config/accounts/neox-testnet.json
```

Supported account sources:

```json
{
  "network": "neox-testnet",
  "accounts": {
    "personal": {
      "type": "keystore",
      "path": "/absolute/path/to/personal-keystore.json",
      "passwordEnv": "OPS_PERSONAL_KEYSTORE_PASSWORD"
    },
    "governor": {
      "type": "privateKeyEnv",
      "env": "OPS_GOVERNOR_PRIVATE_KEY"
    }
  }
}
```

List configured local account aliases:

```sh
npm run ops -- accounts list --network neox-testnet
```

Resolve one local account address:

```sh
npm run ops -- accounts address --network neox-testnet --account personal
```

Validate all configured local account sources:

```sh
npm run ops -- accounts check --network neox-testnet
```

Validate one configured local account source:

```sh
npm run ops -- accounts check --network neox-testnet --account personal
```

`accounts list` never reads secrets. `accounts address` and `accounts check` read only the selected account source unless `check` is run without `--account`.

For keystore accounts, the CLI uses `passwordEnv` when set and prompts for the password otherwise. Absolute keystore paths are used as-is. Relative keystore paths are resolved from the current working directory.

## Read Commands

Read commands do not require an account and never send transactions.

### Bridge Reads

Print native bridge state and registered token bridges:

```sh
npm run ops -- bridge state --network neox-testnet
```

Print one token bridge state:

```sh
npm run ops -- bridge token --network neox-testnet --token <alias-or-address>
```

Check a native claimable by nonce:

```sh
npm run ops -- bridge claimable --network neox-testnet --nonce <nonce>
```

Check a token claimable by nonce:

```sh
npm run ops -- bridge claimable --network neox-testnet --token <alias-or-address> --nonce <nonce>
```

Use `--bridge <address>` on bridge commands to override the configured bridge address for one command.

### Message Bridge Reads

Print message bridge state:

```sh
npm run ops -- message state --network neox-testnet
```

Print one stored message and decoded metadata:

```sh
npm run ops -- message get --network neox-testnet --nonce <nonce>
```

Print result state for one related message nonce:

```sh
npm run ops -- message result --network neox-testnet --nonce <nonce>
```

Print executable state for one stored executable message:

```sh
npm run ops -- message executable --network neox-testnet --nonce <nonce>
```

Use `--message-bridge <address>` on message commands to override the configured message bridge address for one command.

## Write Commands

Write commands are added behind explicit safeguards.

Write commands must require an account:

```sh
npm run ops -- <group> <write-command> --network neox-testnet --account personal
```

Run a write command as a dry run before broadcasting:

```sh
npm run ops -- <group> <write-command> --network neox-testnet --account personal --dry-run true
```

Dry runs build the transaction request and print the transaction summary, but do not send the transaction.

Mainnet writes require explicit confirmation when sending:

```sh
npm run ops -- <group> <write-command> --network neox-mainnet --account personal --yes
```

Without `--yes`, mainnet write commands refuse to send. Mainnet dry-runs do not require `--yes` because they do not broadcast. This is only a safety prompt for accidental use of the wrong network; it is not an authorization mechanism.

Current boolean mode options use explicit values because the CLI parser is strict:

- `--dry-run true`
- `--dry-run false`

Presence-only flags do not take values:

- `--yes`
- `--approve`

### Bridge Claims

Dry-run a native claim transaction:

```sh
npm run ops -- bridge claim-native --network neox-testnet --account personal --nonce <nonce> --dry-run true
```

Send a native claim transaction:

```sh
npm run ops -- bridge claim-native --network neox-testnet --account personal --nonce <nonce>
```

Dry-run a token claim transaction:

```sh
npm run ops -- bridge claim-token --network neox-testnet --account personal --token <alias-or-address> --nonce <nonce> --dry-run true
```

Send a token claim transaction:

```sh
npm run ops -- bridge claim-token --network neox-testnet --account personal --token <alias-or-address> --nonce <nonce>
```

### Bridge Withdrawals

Native withdrawals automatically use the current native bridge fee as `_maxFee` and include the withdrawal amount plus fee as transaction value.

Dry-run a native withdrawal:

```sh
npm run ops -- bridge withdraw-native --network neox-testnet --account personal --to <address> --amount <eth> --dry-run true
```

Token withdrawals automatically use the current token bridge fee as transaction value. If token allowance is too low, rerun with `--approve` to approve the bridge before withdrawing.

Dry-run a token withdrawal:

```sh
npm run ops -- bridge withdraw-token --network neox-testnet --account personal --token <alias-or-address> --to <address> --amount <tokens> --dry-run true
```

Dry-run approval plus token withdrawal:

```sh
npm run ops -- bridge withdraw-token --network neox-testnet --account personal --token <alias-or-address> --to <address> --amount <tokens> --approve --dry-run true
```

### Bridge Funding

Fund the bridge with native currency:

```sh
npm run ops -- bridge fund-native --network neox-testnet --account funder --amount <eth> --dry-run true
```

Fund the bridge with an ERC20 token:

```sh
npm run ops -- bridge fund-token --network neox-testnet --account funder --token <alias-or-address> --amount <tokens> --dry-run true
```

### Bridge Control

Pause or unpause one bridge component:

```sh
npm run ops -- bridge pause --network neox-testnet --account governor --target withdrawals --dry-run true
npm run ops -- bridge unpause --network neox-testnet --account governor --target withdrawals --dry-run true
```

Use `--target token --token <alias-or-address>` for one token bridge. Use `--target all` to apply the action to the main bridge, withdrawals, the native bridge when configured, and the selected token bridge when `--token` is provided. Already-paused or already-unpaused targets are skipped without sending a transaction.

### Bridge Configuration

Configure the native bridge only when it has not been configured yet:

```sh
npm run ops -- bridge configure-native --network neox-testnet --account governor --fee <eth> --min <eth> --max <eth> --max-deposits <count> --decimals-here <count> --decimals-n3 <count> --dry-run true
```

Native setup amounts are parsed as 18-decimal ether values, so `--decimals-here` must be `18`.

Update native bridge withdrawal settings:

```sh
npm run ops -- bridge set-native-fee --network neox-testnet --account governor --amount <eth> --dry-run true
npm run ops -- bridge set-native-min --network neox-testnet --account governor --amount <eth> --dry-run true
npm run ops -- bridge set-native-max --network neox-testnet --account governor --amount <eth> --dry-run true
npm run ops -- bridge set-native-max-deposits --network neox-testnet --account governor --max-deposits <count> --dry-run true
```

Update token bridge withdrawal settings:

```sh
npm run ops -- bridge set-token-fee --network neox-testnet --account governor --token <alias-or-address> --amount <eth> --dry-run true
npm run ops -- bridge set-token-min --network neox-testnet --account governor --token <alias-or-address> --amount <tokens> --dry-run true
npm run ops -- bridge set-token-max --network neox-testnet --account governor --token <alias-or-address> --amount <tokens> --dry-run true
npm run ops -- bridge set-token-max-deposits --network neox-testnet --account governor --token <alias-or-address> --max-deposits <count> --dry-run true
```

Register a token bridge:

```sh
npm run ops -- bridge register-token --network neox-testnet --account governor --token <alias-or-address> --neo-n3-token <address> --fee <eth> --min <tokens> --max <tokens> --max-deposits <count> --scaling-factor <count> --dry-run true
```

If the token alias in deployment config already has `neoN3`, `--neo-n3-token` can be omitted. If `--scaling-factor` is omitted, it defaults to `0`.

### Message Writes

Send commands automatically use the current `sendingFee()` as transaction value and print it in the transaction summary.

Dry-run an executable EVM -> Neo message:

```sh
npm run ops -- message send-executable --network neox-testnet --account personal --message <hex> --store-result true --dry-run true
```

Send a store-only EVM -> Neo message:

```sh
npm run ops -- message send-store-only --network neox-testnet --account personal --message <hex>
```

Send a result message for an executed Neo -> EVM message:

```sh
npm run ops -- message send-result --network neox-testnet --account personal --related-nonce <nonce>
```

Execute a stored Neo -> EVM executable message:

```sh
npm run ops -- message execute --network neox-testnet --account personal --nonce <nonce>
```

Use `--value <eth>` on `message execute` only when the target call needs native value forwarded.

### Message Control

Pause or unpause one message bridge component:

```sh
npm run ops -- message pause --network neox-testnet --account governor --target sending --dry-run true
npm run ops -- message unpause --network neox-testnet --account governor --target sending --dry-run true
```

Use `--target all` to apply the action to the message bridge, sending, and executing components. Already-paused or already-unpaused targets are skipped without sending a transaction.

Set the message sending fee:

```sh
npm run ops -- message set-sending-fee --network neox-testnet --account governor --amount <eth> --dry-run true
```

## Command Reference

Config:

```sh
npm run ops -- config show --network <network>
```

Accounts:

```sh
npm run ops -- accounts list --network <network>
npm run ops -- accounts address --network <network> --account <name>
npm run ops -- accounts check --network <network> [--account <name>]
```

Bridge:

```sh
npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]
npm run ops -- bridge claim-native --network <network> --account <name> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge claim-token --network <network> --account <name> --token <alias-or-address> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge withdraw-native --network <network> --account <name> --to <address> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge withdraw-token --network <network> --account <name> --token <alias-or-address> --to <address> --amount <tokens> [--bridge <address>] [--approve] [--dry-run true] [--yes]
npm run ops -- bridge fund-native --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge fund-token --network <network> --account <name> --token <alias-or-address> --amount <tokens> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge pause --network <network> --account <name> --target <bridge|withdrawals|native|token|all> [--token <alias-or-address>] [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge unpause --network <network> --account <name> --target <bridge|withdrawals|native|token|all> [--token <alias-or-address>] [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge configure-native --network <network> --account <name> --fee <eth> --min <eth> --max <eth> --max-deposits <count> --decimals-here <count> --decimals-n3 <count> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-native-fee --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-native-min --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-native-max --network <network> --account <name> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-native-max-deposits --network <network> --account <name> --max-deposits <count> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-token-fee --network <network> --account <name> --token <alias-or-address> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-token-min --network <network> --account <name> --token <alias-or-address> --amount <tokens> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-token-max --network <network> --account <name> --token <alias-or-address> --amount <tokens> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge set-token-max-deposits --network <network> --account <name> --token <alias-or-address> --max-deposits <count> [--bridge <address>] [--dry-run true] [--yes]
npm run ops -- bridge register-token --network <network> --account <name> --token <alias-or-address> --neo-n3-token <address> --fee <eth> --min <tokens> --max <tokens> --max-deposits <count> [--scaling-factor <count>] [--bridge <address>] [--dry-run true] [--yes]
```

Message bridge:

```sh
npm run ops -- message state --network <network> [--message-bridge <address>]
npm run ops -- message get --network <network> --nonce <nonce> [--message-bridge <address>]
npm run ops -- message result --network <network> --nonce <nonce> [--message-bridge <address>]
npm run ops -- message executable --network <network> --nonce <nonce> [--message-bridge <address>]
npm run ops -- message send-executable --network <network> --account <name> --message <hex> --store-result <true|false> [--message-bridge <address>] [--dry-run true] [--yes]
npm run ops -- message send-store-only --network <network> --account <name> --message <hex> [--message-bridge <address>] [--dry-run true] [--yes]
npm run ops -- message send-result --network <network> --account <name> --related-nonce <nonce> [--message-bridge <address>] [--dry-run true] [--yes]
npm run ops -- message execute --network <network> --account <name> --nonce <nonce> [--message-bridge <address>] [--value <eth>] [--dry-run true] [--yes]
npm run ops -- message pause --network <network> --account <name> --target <bridge|sending|executing|all> [--message-bridge <address>] [--dry-run true] [--yes]
npm run ops -- message unpause --network <network> --account <name> --target <bridge|sending|executing|all> [--message-bridge <address>] [--dry-run true] [--yes]
npm run ops -- message set-sending-fee --network <network> --account <name> --amount <eth> [--message-bridge <address>] [--dry-run true] [--yes]
```
