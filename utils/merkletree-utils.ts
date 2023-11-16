import { MerkleTree } from "merkletreejs";
import { ethers } from "hardhat";
import { assert } from "chai";

interface MerkleTreeResult {
  proof: string[];
  root: string;
}

interface MerkleProofResult {
  proof: string[];
  path: number;
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

export async function getMerkleProof(leaves: string[], targetLeaf: string): Promise<MerkleProofResult> {
  //for UT, only construct a 32-leaf merkle tree
  let leafNodes = new Array(32).fill(ethers.ZeroHash);
  assert(leaves.length > 0 && leaves.length <= 32, "leaves length should be between 1 and 32");
  for (let i = 0; i < leaves.length; i++) {
    leafNodes[i] = leaves[i];
  }
  const merkletree = new MerkleTree(leafNodes, ethers.sha256, { sortPairs: false });
  const position_Proof = merkletree.getPositionalHexProof(targetLeaf);
  const root = merkletree.getHexRoot();
  //traverse the proof to get proof and path
  const proof = [];
  let path = 0;
  for (let i = 0; i < position_Proof.length; i++) {
    proof.push(position_Proof[i][1].toString());
    path += ethers.toNumber(position_Proof[i][0]) * 2 ** i;
  }
  return { proof, path, root };

}
