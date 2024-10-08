import { Wallet } from "ethers";
import { ethers } from "hardhat";
import { TestToken, TestBridge } from "../../typechain-types/contracts/tests";
import { MAX_FEE_PER_GAS, MAX_PRIORITY_FEE_PER_GAS } from "./constants";
import { fundIfLocalNetwork } from "./network";

export async function registerToken(bridge: TestBridge, governor: Wallet, token: TestToken, n3TokenAddress: string) {
    await registerTokenWithScalingFactor(bridge, governor, token, n3TokenAddress, 0n);
}

export async function registerTokenWithScalingFactor(bridge: TestBridge, governor: Wallet, token: TestToken, n3TokenAddress: string, decimalScalingFactor: bigint) {
    await fundIfLocalNetwork([governor.address]);
    console.log("\n#####################################################################");
    console.log("######################### Token Registration ########################");
    console.log("#####################################################################");
    const tokenConfig = {
        neoN3Token: n3TokenAddress,
        decimalScalingFactor: decimalScalingFactor,
        fee: ethers.parseEther("0.1"),
        minAmount: ethers.parseEther("1"),
        maxAmount: ethers.parseEther("10000"),
        maxDeposits: 100,
    }

    const registration = await bridge.connect(governor).registerToken(await token.getAddress(), tokenConfig, { maxFeePerGas: MAX_FEE_PER_GAS, maxPriorityFeePerGas: MAX_PRIORITY_FEE_PER_GAS });
    await registration.wait();
    console.log("# Token Configuration");
    console.log("Token Address: ", await token.getAddress());
    console.log("Token Config:  ", tokenConfig);
}
