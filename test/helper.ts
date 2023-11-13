import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export const validator1 = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
export const validator2 = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
export const validator3 = "0x90F79bf6EB2c4f870365E785982E1f101E93b906";
export const validator4 = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";
export const validator5 = "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc";
export const validator6 = "0x976EA74026E726554dB657fA54763abd0C3a0aa9";
export const validator7 = "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955";

export const to1 = "0x71be63f3384f5fb98995898a86b02fb2426c5788";
export const to2 = "0xfabb0ac9d68b0b445fb7357272ff202c5651694a";
export const to3 = "0x1cbd3b2770909d4e10f157cabc84c7264073c9ec";
export const to4 = "0xdf3e18d64bc6a983f673ab319ccae4f1a57c7097";
export const to5 = "0xcd3b766ccdd6ae721141f452c550ca635964ce71";
export const to6 = "0x2546bcd3c84621e976d8185a91a922ae77ecec30";
export const to7 = "0xbda5747bfd65f08deb54cb465eb87d40e51b197e";
export const to8 = "0xdd2fd4581271e230360230f9337d5c0430bf44c0";
export const to9 = "0x8626f6940e2eb28930efb4cef49b2d1f2c9c1199";
export const to0 = "0xbcd4042de499d14e55001ccbb24a551f3b954096";

export function toEthDecimals(value: bigint): bigint {
    return ethers.parseUnits(value.toString(), 10);
}

export function concatRoots(proofs: any): Uint8Array {
    let concat = proofs[0].root;
    for (let i = 1; i < proofs.length; i++) {
        concat = ethers.concat([concat, proofs[i].root]);
    }
    const concatAndHashed = ethers.keccak256(concat);
    return ethers.getBytes(concatAndHashed);
}

export async function fundContract(bridgeContract: any, funder: HardhatEthersSigner) {
    const amount = ethers.parseEther("100.0");
    const to = await bridgeContract.getAddress()
    await funder.sendTransaction({ to, value: amount });
}

export async function hashDepositOrWithdrawal(nonce: number, amount: bigint, to: string): Promise<string> {
    const packData = ethers.solidityPacked(["uint64", "uint64", "address"], [nonce, amount, to]);
    const hashData = ethers.sha256(packData);
    return hashData;
}

export async function computeRoot(previouRoot: string, newHash: string): Promise<string> {
    return ethers.sha256(ethers.solidityPacked(["bytes32", "bytes32"], [ethers.getBytes(previouRoot), ethers.getBytes(newHash)]));
}
