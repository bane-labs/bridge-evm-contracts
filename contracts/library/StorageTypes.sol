// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Currently supported bridge types:
// - Gas (native transfer)
// - Neo (ERC20 transfer)
// - ERC20 (transfer(address to, uint256 value))
// Future supported bridge types:
// - (ERC721 (safeMint(address to, uint256 tokenId), burn(uint256 tokenId)))
library StorageTypes {
    struct Claimable {
        address to;
        uint256 amount;
    }

    struct Change {
        ParamType paramType;
        uint256 pendingUntilBlock;
        uint256 executableUntilBlock;
        uint256 value;
    }

    enum ParamType {
        Fee,
        MinAmount,
        MaxAmount,
        MaxDeposits
    }

    // Gas Bridge

    struct GasBridge {
        bool paused;
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
        uint256 maxDeposits; // This should be used by the validators to decide for which deposit to sign if there are lots of deposits in a single block on the source chain, e.g., if this value is 50 and on the source chain there's 60 deposits in a single block, the resulting roots of deposit 50 and 60 should be signed and provided to the relayer.
    }

    // Token Bridges

    /**
     * The execution type is used to specifies the behaviour when executing a token distribution from another chain.
     * Currently, there's only two types of a token distribution, which both use a simple ERC20's "transfer(address,uint256)" function, while the type NEO additionally adds 18 decimal places when depositing, since Neo does not have decimal places on Neo N3.
     * How the distribution handling for other types will be implemented is still under discussion. However, for ERC721, the functions in mind are "mint(address,uint256)", "safeMint(address,uint256)", "transferFrom(address,uint256)" or "safeTransferFrom(address,uint256)". As seen from these function declarations, similar to ERC20, they all use the same parameter types, i.e., besides the function call, the complete existing execution logic and chain computation can be reused in depositToken().
     */
    enum ExecutionType {
        NEO,
        ERC20
        // ERC721
    }

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
        // Execution details
        ExecutionType executionType;
    }
}
