# Ops CLI

The ops CLI is the preferred way to inspect configured bridge deployments and local operator accounts without using Hardhat tasks or `hh vars`.

Run it through npm:

```sh
npm run ops -- help
npm run ops -- <group> --help
```

Available groups:

- `config` inspects resolved network, deployment, token, and account config.
- `accounts` inspects local account aliases and resolves account addresses.
- `bridge` reads token bridge state from a configured network.
- `message` reads message bridge state from a configured network.

## Config Files

Committed config:

- `config/networks/<network>.json` contains RPC and chain metadata.
- `config/deployments/<network>.json` contains deployed contract addresses and token aliases.
- `config/accounts/<network>.example.json` documents the local account format.

Local config:

- `config/deployments/<network>.local.json` can override deployment values locally.
- `config/accounts/<network>.json` contains local account sources and is ignored by git.

Every config file declares its network name. The CLI rejects mismatches, so a mainnet command cannot accidentally load a testnet accounts or deployment file.

## Common Commands

Show resolved config:

```sh
npm run ops -- config show --network neox-testnet
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

`accounts list` never reads secrets. `accounts address` and `accounts check` read only the selected account source unless `check` is run without `--account`.

For keystore accounts, the CLI uses `passwordEnv` when set and prompts for the password otherwise. Absolute keystore paths are used as-is. Relative keystore paths are resolved from the current working directory.

## Write Command Safety

Write commands are added behind explicit safeguards. Read commands do not use these options.

Write commands must require an account:

```sh
npm run ops -- <group> <write-command> --network neox-testnet --account personal
```

Run a write command as a dry run before broadcasting:

```sh
npm run ops -- <group> <write-command> --network neox-testnet --account personal --dry-run true
```

Dry runs build the transaction request and print the transaction summary, but do not send the transaction.

Mainnet writes require explicit confirmation:

```sh
npm run ops -- <group> <write-command> --network neox-mainnet --account personal --yes true
```

Without `--yes true`, mainnet write commands refuse to send. This is only a safety prompt for accidental use of the wrong network; it is not an authorization mechanism.

Current boolean options use explicit values because the CLI parser is strict:

- `--dry-run true`
- `--dry-run false`
- `--yes true`
