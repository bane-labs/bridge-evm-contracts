// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20Capped {
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}

// Currently supported bridge types:
// - Gas (native transfer)
// Future supported bridge types:
// - ERC20Capped (transfer(address to, uint256 value))
// - ERC20Uncapped (mint(address to, uint256 amount), burn(uint256 value))
// - (ERC721 (safeMint(address to, uint256 tokenId), burn(uint256 tokenId)))
library BridgeStorageTypes {
    struct Claimable {
        address to;
        uint256 amount;
    }

    // Gas Bridge

    struct GasBridge {
        State depositState;
        State withdrawalState;
        GasConfig config;
    }

    struct State {
        uint256 nonce;
        bytes32 root;
    }

    struct GasConfig {
        uint256 fee;
        uint256 minAmount;
        uint256 maxAmount;
        uint8 maxDepositsPerDistribution;
        uint256[2] gap; // not needed
    }

    // Token Bridges

    enum TokenType {
        ERC20Capped
        // ERC20Uncapped
        // ERC721
    }

    struct TokenTypeConfig {
        uint256 fee;
        uint8 maxDepositsPerDistribution;
    }

    struct TokenBridge {
        bool registered; // used for simple existence check
        State depositState;
        State withdrawalState;
        TokenTypeConfig config;
    }

    struct TokenConfig {
        address contractAddress;
        uint256 minAmount;
        uint256 maxAmount;
    }
}
