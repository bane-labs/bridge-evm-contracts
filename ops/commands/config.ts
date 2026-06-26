import { loadOpsConfig } from "../config/load";
import { printResolvedContext } from "../format";

export function runConfigCommand(args: string[]): void {
  const [command, ...rest] = args;
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

function parseOptions(args: string[]): Record<string, string> {
  const options: Record<string, string> = {};
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (!arg.startsWith("--")) throw new Error(`Unexpected positional argument: ${arg}`);
    const key = arg.slice(2);
    const value = args[++i];
    if (!value || value.startsWith("--")) throw new Error(`Missing value for --${key}`);
    options[key] = value;
  }
  return options;
}

function requireOption(options: Record<string, string>, key: string): string {
  const value = options[key];
  if (!value) throw new Error(`Missing required option --${key}`);
  return value;
}
