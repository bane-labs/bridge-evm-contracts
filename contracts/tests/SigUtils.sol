// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/BridgeLib.sol";

contract SigUtils {
    uint256 internal user0PrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 internal user1PrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 internal user2PrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 internal user3PrivateKey = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    uint256 internal user4PrivateKey = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;
    uint256 internal user5PrivateKey = 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba;
    uint256 internal user6PrivateKey = 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e;

    uint256 internal valid_user0PrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff87;
    uint256 internal valid_user1PrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b786907;
    uint256 internal valid_user2PrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab3657;
    uint256 internal valid_user3PrivateKey = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a7;
    uint256 internal valid_user4PrivateKey = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a349267;
    uint256 internal valid_user5PrivateKey = 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffb7;
    uint256 internal valid_user6PrivateKey = 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec15647;

    // computes the hash of a permit
    function getStructHash(BridgeLib.DepositData memory _depositData) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_depositData.nonce, _depositData.to, _depositData.amount));
    }

    function getSignedHash(bytes32 _hash) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(block.chainid, _hash)))
        );
    }
}
