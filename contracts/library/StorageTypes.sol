// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Currently supported bridge types:
// - Native Coin (native transfer)
// - Neo (ERC20 transfer)
// - ERC20 (transfer(address to, uint256 value))
// Future supported bridge types:
// - (ERC721 (safeMint(address to, uint256 tokenId), burn(uint256 tokenId)))
library StorageTypes {
    struct Claimable {
        address to;
        uint256 amount;
    }

    // Native Bridge

    struct NativeBridge {
        bool paused;
        State depositState;
        State withdrawalState;
        NativeConfig config;
    }

    struct State {
        uint256 nonce;
        bytes32 root;
    }

    struct NativeConfig {
        uint256 fee;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 maxDeposits; // This should be used by the validators to decide for which deposit to sign if there are lots of deposits in a single block on the source chain, e.g., if this value is 50 and on the source chain there's 60 deposits in a single block, the resulting roots of deposit 50 and 60 should be signed and provided to the relayer.
        uint256 decimalScalingFactor;
    }

    // Token Bridges

    struct TokenBridge {
        bool paused;
        State depositState;
        State withdrawalState;
        TokenConfig config;
    }

    struct TokenConfig {
        address neoN3Token;
        uint256 fee;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 maxDeposits;
        // The decimal scaling factor should be used if the token on this chain has more decimal precision than the token on the other chain.
        // For example, if the token on this chain has 18 decimals and the token on the other chain has 8 decimals, the decimal scaling factor should be 10.
        uint256 decimalScalingFactor;
    }
}
