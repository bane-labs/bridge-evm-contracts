# EVM Contracts for the N3 - Neo X Bridge

This repository is used for the development of the Neo X contracts for the native `Neo N3 <-> Neo X` bridge.

The contracts in `./contracts` are under development. The contract artifacts for each corresponding release are committed in the `./release-artifacts` directory. For the source code, the corresponding tagged commit can be retrieved.

## Operational CLI

Use `npm run ops -- help` to inspect configured bridge deployments and local operator accounts.

See [docs/ops-cli.md](docs/ops-cli.md) for command examples and local account config. See [docs/ops-fork-smoke.md](docs/ops-fork-smoke.md) for testing the ops CLI against a local Neo X mainnet fork.

Legacy operational script workflows move into the ops CLI once they are covered there.

## Foundry Deploy Scripts

Use the Foundry scripts under [script/deploy](script/deploy) for fresh bridge stack deployments. The deploy scripts cover BridgeManagement, Bridge, MessageBridge, ExecutionManager, and the governor-only ExecutionManager link step.

Token bridge registration is not part of deployment. Use the ops CLI `bridge register-token` command after the relevant token contract and bridge deployment are known.

## Deployments on Neo X Mainnet and Testnet

| Contract         | Hash                                         |
| -----------------| -------------------------------------------- |
| TokenBridge      | `0x1212000000000000000000000000000000000004` |
| BridgeManagement | `0x1212000000000000000000000000000000000005` |
| MessageBridge    | `0x1212000000000000000000000000000000000009` |
| ExecutionManager | `0x85776439bbE26A3B6F91baB0fb8Ef3fDc769f385` |
