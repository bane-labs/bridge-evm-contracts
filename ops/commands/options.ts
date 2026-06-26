export type CommandOptions = Record<string, string>;

export function parseOptions(args: string[]): CommandOptions {
  const options: CommandOptions = {};
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

export function requireOption(options: CommandOptions, key: string): string {
  const value = options[key];
  if (!value) throw new Error(`Missing required option --${key}`);
  return value;
}
