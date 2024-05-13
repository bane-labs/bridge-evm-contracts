// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Currently supported bridge types:
// - Gas (native transfer)
// Future supported bridge types:
// - ERC20Capped (transfer(address to, uint256 value))
// - ERC20Uncapped (mint(address to, uint256 amount), burn(uint256 value))
// - (ERC721 (safeMint(address to, uint256 tokenId), burn(uint256 tokenId)))
library StorageTypes {
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
        uint8 maxDeposits;
        bool locked;
        uint256[2] gap; // not needed
    }

    // Token Bridges

    /**
     * The token type is used to specifies the behaviour when executing a token distribution from another chain.
     * Currently, there's only one type of a token distribution, which uses a simple ERC20's "transfer(address,uint256)" function.
     * How the distribution handling for other token types will be implemented is still under discussion. However, for ERC20Uncapped, and ERC721, the functions in mind are "mint(address,uint256)", and "safeMint(address,uint256)", respectively. As seen from these function declarations, similar to ERC20Capped, they all use the same parameter types, i.e., besides the function call, the complete existing execution logic and chain computation can be reused in depositToken().
     */
    enum TokenType {
        ERC20Capped
        // ERC20Uncapped
        // ERC721
    }

    struct TokenBridge {
        bool locked;
        State depositState;
        State withdrawalState;
        TokenConfig config;
    }

    struct TokenConfig {
        TokenType tokenType;
        address neoN3Token;
        uint256 fee;
        uint256 minAmount;
        uint256 maxAmount;
        uint256 maxDeposits;
    }
}
