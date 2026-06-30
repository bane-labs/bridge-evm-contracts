# Ops Fork Smoke Workflow

Use this workflow to test the ops CLI against a local Anvil fork of Neo X mainnet without broadcasting transactions to mainnet.

This covers the new `ops/` CLI only. It does not test the legacy `scripts/` directory.

## Start the Fork

Provide a Neo X mainnet RPC URL, then start Anvil:

```sh
export NEOX_MAINNET_RPC_URL=<neo-x-mainnet-rpc-url>
npm run ops:fork:mainnet
```

The fork profile expects Anvil on `http://127.0.0.1:8545` with chain ID `47763`.

Some ops reads intentionally probe Solidity getters until they revert, for example `registeredTokens(index)` at the end of the dynamic token array. The CLI handles those expected reverts, but Anvil may still log them as failed RPC calls in the fork terminal.

## Configure a Local Account

Create an ignored account config for the fork:

```sh
cp config/accounts/neox-mainnet-fork.example.json config/accounts/neox-mainnet-fork.json
```

For Anvil's default first account:

```sh
export OPS_FORK_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

This is a public development private key. Do not use it outside local fork testing.

## Basic Smoke Checks

These commands should be runnable on a healthy fork:

```sh
npm run ops -- config show --network neox-mainnet-fork
npm run ops -- accounts check --network neox-mainnet-fork
npm run ops -- bridge state --network neox-mainnet-fork
npm run ops -- message state --network neox-mainnet-fork
```

Dry-run write commands build transaction requests but do not broadcast:

```sh
npm run ops -- message send-store-only --network neox-mainnet-fork --account anvil --message 0x1234 --dry-run true
npm run ops -- message send-executable --network neox-mainnet-fork --account anvil --message 0x1234 --store-result true --dry-run true
```

If the mainnet fork has paused sending or a paused bridge, these commands should fail before transaction construction with a clear preflight error.

## Fixture-Dependent Checks

These commands require known state in the forked block.

Bridge claim checks need a known claimable nonce:

```sh
npm run ops -- bridge claimable --network neox-mainnet-fork --nonce <claimable-nonce>
npm run ops -- bridge claim-native --network neox-mainnet-fork --account anvil --nonce <claimable-nonce> --dry-run true
```

Token checks need a configured token alias or a direct token address:

```sh
npm run ops -- bridge token --network neox-mainnet-fork --token <alias-or-address>
npm run ops -- bridge claimable --network neox-mainnet-fork --token <alias-or-address> --nonce <claimable-nonce>
npm run ops -- bridge claim-token --network neox-mainnet-fork --account anvil --token <alias-or-address> --nonce <claimable-nonce> --dry-run true
```

Message read and execute checks need known message nonces:

```sh
npm run ops -- message get --network neox-mainnet-fork --nonce <message-nonce>
npm run ops -- message result --network neox-mainnet-fork --nonce <related-message-nonce>
npm run ops -- message executable --network neox-mainnet-fork --nonce <executable-message-nonce>
npm run ops -- message execute --network neox-mainnet-fork --account anvil --nonce <executable-message-nonce> --dry-run true
npm run ops -- message send-result --network neox-mainnet-fork --account anvil --related-nonce <executed-message-nonce> --dry-run true
```

If no matching state exists at the forked block, these commands should fail with a clear missing claimable, missing message, missing result, already executed, expired, or paused-state error.

## Notes

- `neox-mainnet-fork` intentionally uses separate config from `neox-mainnet`.
- The fork deployment file mirrors current Neo X mainnet addresses.
- Mainnet `--yes` protection is not required on `neox-mainnet-fork`, but dry-run is still recommended before sending.
- Use a fixed Anvil fork block when comparing results across machines.
