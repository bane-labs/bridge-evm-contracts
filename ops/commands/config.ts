import { loadOpsConfig } from "../config/load";
import { printResolvedContext } from "../format";
import { hasHelpArg, isHelpArg, parseOptions, requireOption } from "./options";

export function runConfigCommand(args: string[]): void {
  const [command, ...rest] = args;
  if (!command || isHelpArg(command) || hasHelpArg(rest)) {
    printConfigHelp();
    return;
  }
  if (command !== "show") {
    throw new Error(`Unknown config command: ${command ?? "(missing)"}`);
  }
  const options = parseOptions(rest);
  const network = requireOption(options, "network");
  const config = loadOpsConfig(network);

  printResolvedContext(config);
  console.log(JSON.stringify({
    network: config.network,
    contracts: config.deployment.contracts,
    tokens: config.deployment.tokens ?? {},
    accounts: Object.keys(config.accounts.accounts ?? {}),
    sources: config.sources
  }, null, 2));
}

function printConfigHelp(): void {
  console.log(`Config commands

Usage:
  npm run ops -- config show --network <network>

Commands:
  show    Print resolved network, deployment, token, account, and source config.
`);
}
