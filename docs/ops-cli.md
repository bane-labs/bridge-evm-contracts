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

`accounts list` never reads secrets. `accounts address` reads only the selected account source. For keystore accounts, the CLI uses `passwordEnv` when set and prompts for the password otherwise.
