# Foundry Deploy Scripts

These scripts are the Foundry deployment path for the current bridge deployment profile. They intentionally keep using the existing `Test*` contracts because the production contracts do not yet expose deploy-safe initializers. Contract changes to remove that requirement should be handled separately.

Token deployment and token bridge registration are not part of this deploy suite. Use the ops CLI `bridge register-token` command after the bridge stack and token addresses are known.

## Manifest

Scripts share deployment context through a JSON manifest:

```text
deployments/foundry/<network>.json
```

Set `DEPLOYMENT_NETWORK` to control the filename. The default `deployments/foundry` output directory is the only write-enabled deploy path in `foundry.toml`. If you set `DEPLOYMENT_MANIFEST` or `DEPLOYMENT_MANIFEST_DIR` to another path, update `fs_permissions` accordingly. Individual scripts read prerequisites from this manifest and fail clearly if a dependency is missing.

## Required Role Inputs

`DeployBridgeManagement` and `DeployBridgeSuite` require:

```text
BRIDGE_OWNER
BRIDGE_RELAYER
BRIDGE_VALIDATOR01
BRIDGE_VALIDATOR02
BRIDGE_GOVERNOR
```

Optional:

```text
BRIDGE_VALIDATOR_THRESHOLD     default: 2
BRIDGE_SECURITY_GUARD          default: BRIDGE_OWNER
BRIDGE_FUNDER                  default: BRIDGE_OWNER
MESSAGE_BRIDGE_FEE             default: 100000000000000000
MESSAGE_BRIDGE_MAX_MESSAGE_SIZE default: 10240
MESSAGE_BRIDGE_MAX_NR_MESSAGES default: 100
MESSAGE_BRIDGE_EXECUTION_WINDOW_SECONDS default: 86400
GOVERNOR_PRIVATE_KEY           links ExecutionManager during DeployBridgeSuite
```

`BRIDGE_VALIDATOR_THRESHOLD` must be between `1` and the number of configured validators. The current deploy profile uses the fixed `BRIDGE_VALIDATOR01` and `BRIDGE_VALIDATOR02` set, so valid values are `1` or `2`.

The `MESSAGE_BRIDGE_*` overrides are parsed with Foundry's `vm.envUint`, so provide raw `uint256` values, not Solidity unit expressions. `MESSAGE_BRIDGE_FEE` is wei, `MESSAGE_BRIDGE_MAX_MESSAGE_SIZE` is bytes, and `MESSAGE_BRIDGE_EXECUTION_WINDOW_SECONDS` is seconds. For example, use `MESSAGE_BRIDGE_FEE=100000000000000000` for `0.1 ether`.

Without `GOVERNOR_PRIVATE_KEY`, `DeployBridgeSuite` deploys all contracts and writes the manifest, but leaves `ExecutionManager` unlinked. Run `deploy:configure-execution-manager` with a governor broadcaster to link it.

## ExecutionManager Configuration

`DeployExecutionManager` only deploys the execution contract. The MessageBridge must also be told which ExecutionManager it should use for executable messages. That configuration is a governor-only call on MessageBridge, so it may need to happen in a separate transaction from deployment.

`ConfigureExecutionManager` reads `messageBridge` and `executionManager` from the manifest and calls `setExecutionManager` on the MessageBridge. Use it when:

- contracts were deployed one-by-one, after both MessageBridge and ExecutionManager exist
- `DeployBridgeSuite` was run without `GOVERNOR_PRIVATE_KEY`
- the deployer key is intentionally separate from the governor key

## Commands

Deploy the full dependency graph:

```sh
npm run deploy:bridge-suite -- --rpc-url "$RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY"
```

Or deploy units individually:

```sh
npm run deploy:bridge-management -- --rpc-url "$RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY"
npm run deploy:bridge -- --rpc-url "$RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY"
npm run deploy:message-bridge -- --rpc-url "$RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY"
npm run deploy:execution-manager -- --rpc-url "$RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY"
npm run deploy:configure-execution-manager -- --rpc-url "$RPC_URL" --private-key "$GOVERNOR_PRIVATE_KEY"
```
