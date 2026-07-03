import { loadOpsConfig } from "../config/load";
import { bridgeClaimNative, bridgeClaimToken } from "./bridgeClaims";
import {
  bridgeConfigureNative,
  bridgeSetNativeFee,
  bridgeSetNativeMax,
  bridgeSetNativeMaxDeposits,
  bridgeSetNativeMin,
  bridgeSetTokenFee,
  bridgeSetTokenMax,
  bridgeSetTokenMaxDeposits,
  bridgeSetTokenMin
} from "./bridgeConfigure";
import { bridgeControl } from "./bridgeControl";
import { bridgeFundNative, bridgeFundToken } from "./bridgeFunding";
import { bridgeClaimable, bridgeState, bridgeToken } from "./bridgeRead";
import { bridgeRegisterToken } from "./bridgeRegister";
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
  if (command === "fund-native") {
    await bridgeFundNative(config, options);
    return;
  }
  if (command === "fund-token") {
    await bridgeFundToken(config, options);
    return;
  }
  if (command === "pause") {
    await bridgeControl(config, options, "pause");
    return;
  }
  if (command === "unpause") {
    await bridgeControl(config, options, "unpause");
    return;
  }
  if (command === "configure-native") {
    await bridgeConfigureNative(config, options);
    return;
  }
  if (command === "set-native-fee") {
    await bridgeSetNativeFee(config, options);
    return;
  }
  if (command === "set-native-min") {
    await bridgeSetNativeMin(config, options);
    return;
  }
  if (command === "set-native-max") {
    await bridgeSetNativeMax(config, options);
    return;
  }
  if (command === "set-native-max-deposits") {
    await bridgeSetNativeMaxDeposits(config, options);
    return;
  }
  if (command === "set-token-fee") {
    await bridgeSetTokenFee(config, options);
    return;
  }
  if (command === "set-token-min") {
    await bridgeSetTokenMin(config, options);
    return;
  }
  if (command === "set-token-max") {
    await bridgeSetTokenMax(config, options);
    return;
  }
  if (command === "set-token-max-deposits") {
    await bridgeSetTokenMaxDeposits(config, options);
    return;
  }
  if (command === "register-token") {
    await bridgeRegisterToken(config, options);
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

Commands:
  state       Print native bridge state and registered token bridges.
  token       Print state for one token bridge.
  claimable   Check native or token claimable state for one nonce.
  claim-native  Claim native funds for one nonce.
  claim-token   Claim token funds for one token and nonce.
  withdraw-native  Withdraw native funds to Neo N3.
  withdraw-token   Withdraw tokens to Neo N3.
  fund-native  Fund the bridge with native currency.
  fund-token   Fund the bridge with an ERC20 token.
  pause       Pause one bridge component.
  unpause     Unpause one bridge component.
  configure-native  Configure the native bridge when it has not been configured yet.
  set-native-*  Update native bridge withdrawal settings.
  set-token-*   Update token bridge withdrawal settings.
  register-token  Register a token bridge.

Options:
  --network      Required. One of local, neox-devnet, neox-testnet, neox-mainnet, neox-mainnet-fork.
  --account      Required for write commands. Account alias from config/accounts/<network>.json.
  --bridge       Optional bridge address override.
  --token        Token alias from deployment config or direct token address.
  --nonce        Claimable nonce.
  --to           Recipient address on Neo N3 represented as an address.
  --amount       Withdrawal amount, in native ether units or token units.
  --fee          Native bridge setup fee in ether units.
  --min          Native bridge setup minimum withdrawal amount in ether units.
  --max          Native bridge setup maximum withdrawal amount in ether units.
  --neo-n3-token Neo N3 token address represented as an address.
  --target       Control target: bridge, withdrawals, native, token, or all.
  --decimals-here  Native asset decimals on this chain. Must be 18.
  --decimals-n3    Native asset decimals on Neo N3.
  --scaling-factor Token decimal scaling factor.
  --approve      For token withdrawals, approve token spending before withdrawing if needed.
  --max-deposits Maximum deposits accepted in one relay batch.
  --max-tokens   Maximum registeredTokens(index) entries to read for state.
  --dry-run      Use --dry-run true to print the transaction without sending.
  --yes          Required for mainnet write commands.
`);
}
