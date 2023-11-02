import { MerkleTree } from "merkletreejs";
import { ethers } from "hardhat";

interface MerkleTreeResult {
  proof: string[];
  root: string;
}

export async function createMerkleTree(nonce: number, to: string, amount: bigint): Promise<MerkleTreeResult> {
  const tokens = [
    "0x00",
    ethers.solidityPacked(["uint32", "address", "uint64"], [nonce, to, amount]),
  ];
  const leaf = tokens.map(x => ethers.sha256(x))
  const merkletree = new MerkleTree(leaf, ethers.sha256, { sortPairs: false });

  const proof = merkletree.getHexProof(leaf[1]);
  const root = merkletree.getHexRoot();
  return { proof, root };
}
