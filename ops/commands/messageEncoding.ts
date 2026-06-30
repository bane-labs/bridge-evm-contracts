import { ethers } from "ethers";
import { resolveTokenAddress } from "../config/load";
import { OpsConfig } from "../config/types";
import { parseAddress, parseAmount, parseBooleanOption, parseBytes } from "../tx/parse";
import { CommandOptions, requireOption } from "./options";

export function messageEncodeBalanceOf(config: OpsConfig, options: CommandOptions): void {
  const tokenInput = requireOption(options, "token");
  const tokenAddress = resolveTokenAddress(config, tokenInput);
  const holder = parseAddress(requireOption(options, "holder"), "holder");
  const allowFailure = parseBooleanOption(options["allow-failure"], "--allow-failure");
  const value = options.value ? parseAmount(options.value, 18, "value") : 0n;

  const erc20Interface = new ethers.Interface(["function balanceOf(address account) view returns (uint256)"]);
  const callData = erc20Interface.encodeFunctionData("balanceOf", [holder]);
  const message = encodeEvmCall(tokenAddress, allowFailure, value, callData);

  console.log("Encoded balanceOf executable message");
  console.log(`  Network:       ${config.networkName}`);
  console.log(`  Token:         ${tokenAddress}`);
  console.log(`  Holder:        ${holder}`);
  console.log(`  Allow failure: ${allowFailure ? "yes" : "no"}`);
  console.log(`  Value:         ${ethers.formatEther(value)} (${value.toString()} wei)`);
  console.log(`  Call data:     ${callData}`);
  console.log(`  Message:       ${message}`);
}

export function messageDecodeUint256(options: CommandOptions): void {
  const data = parseBytes(requireOption(options, "data"), "data");
  const [decoded] = ethers.AbiCoder.defaultAbiCoder().decode(["uint256"], data) as unknown as [bigint];

  console.log("Decoded uint256");
  console.log(`  Raw:   ${decoded.toString()}`);
}

function encodeEvmCall(target: string, allowFailure: boolean, value: bigint, callData: string): string {
  return ethers.AbiCoder.defaultAbiCoder().encode(
    ["tuple(address target, bool allowFailure, uint256 value, bytes callData)"],
    [{ target, allowFailure, value, callData }]
  );
}
