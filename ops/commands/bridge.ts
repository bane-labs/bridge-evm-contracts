import { loadOpsConfig } from "../config/load";
import { bridgeClaimNative, bridgeClaimToken } from "./bridgeClaims";
import { bridgeClaimable, bridgeState, bridgeToken } from "./bridgeRead";
import { bridgeWithdrawNative, bridgeWithdrawToken } from "./bridgeWithdrawals";
import { hasHelpFlag, isHelpFlag, parseOptions, requireOption } from "./options";

export async function runBridgeCommand(args: string[]): Promise<void> {
  const [command, ...rest] = args;
  if (!command || isHelpFlag(command) || hasHelpFlag(rest)) {
    printBridgeHelp();
    return;
  }
  const options = parseOptions(rest, new Set(["yes", "approve"]));
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);

  if (command === "state") {
    await bridgeState(config, options);
    return;
  }
  if (command === "claimable") {
    await bridgeClaimable(config, options);
    return;
  }
  if (command === "token") {
    await bridgeToken(config, options);
    return;
  }
  if (command === "claim-native") {
    await bridgeClaimNative(config, options);
    return;
  }
  if (command === "claim-token") {
    await bridgeClaimToken(config, options);
    return;
  }
  if (command === "withdraw-native") {
    await bridgeWithdrawNative(config, options);
    return;
  }
  if (command === "withdraw-token") {
    await bridgeWithdrawToken(config, options);
    return;
  }
  throw new Error(`Unknown bridge command: ${command ?? "(missing)"}`);
}

function printBridgeHelp(): void {
  console.log(`Bridge commands

Usage:
  npm run ops -- bridge state --network <network> [--bridge <address>] [--max-tokens <count>]
  npm run ops -- bridge token --network <network> --token <alias-or-address> [--bridge <address>]
  npm run ops -- bridge claimable --network <network> --nonce <nonce> [--token <alias-or-address>] [--bridge <address>]
  npm run ops -- bridge claim-native --network <network> --account <name> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge claim-token --network <network> --account <name> --token <alias-or-address> --nonce <nonce> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge withdraw-native --network <network> --account <name> --to <address> --amount <eth> [--bridge <address>] [--dry-run true] [--yes]
  npm run ops -- bridge withdraw-token --network <network> --account <name> --token <alias-or-address> --to <address> --amount <tokens> [--bridge <address>] [--approve] [--dry-run true] [--yes]

Commands:
  state       Print native bridge state and registered token bridges.
  token       Print state for one token bridge.
  claimable   Check native or token claimable state for one nonce.
  claim-native  Claim native funds for one nonce.
  claim-token   Claim token funds for one token and nonce.
  withdraw-native  Withdraw native funds to Neo N3.
  withdraw-token   Withdraw tokens to Neo N3.

Options:
  --network      Required. One of local, neox-devnet, neox-testnet, neox-mainnet.
  --account      Required for write commands. Account alias from config/accounts/<network>.json.
  --bridge       Optional bridge address override.
  --token        Token alias from deployment config or direct token address.
  --nonce        Claimable nonce.
  --to           Recipient address on Neo N3 represented as an address.
  --amount       Withdrawal amount, in native ether units or token units.
  --approve      For token withdrawals, approve token spending before withdrawing if needed.
  --max-tokens   Maximum registeredTokens(index) entries to read for state.
  --dry-run      Use --dry-run true to print the transaction without sending.
  --yes          Required for mainnet write commands.
`);
}
