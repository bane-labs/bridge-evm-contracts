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
    // Generic Types

    struct TypeConfig {
        uint256 fee;
        uint8 maxDepositsPerDistribution;
    }

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
        uint256[2] gap;
    }

    // ERC20 Capped

    struct ERC20CappedBridge {
        State depositState;
        State withdrawalState;
        ERC20CappedConfig config;
    }

    struct ERC20CappedConfig {
        uint256 minAmount;
        uint256 maxAmount;
        IERC20Capped token;
        uint256[2] gap;
    }
}
