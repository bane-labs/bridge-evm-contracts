// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev This contract is a proxy contract that delegates calls to an implementation contract.
 */
contract BridgeProxy {
    address public implementation;
    // Todo: The owner of this contract should not be restricted to a single key-pair.
    address public owner;

    constructor(address _implementation) {
        implementation = _implementation;
        owner = msg.sender;
    }

    // Todo: Use a multi-sig wallet to allow upgrading the implementation contract
    modifier onlyOwner() {
        require(owner == msg.sender, "Not owner");
        _;
    }

    function upgrade(address _newImplementation) external onlyOwner {
        // Todo: Implement logic to use multi-sig wallet to upgrade the implementation contract
        implementation = _newImplementation;
    }

    fallback() external payable {
        address _impl = implementation;
        require(_impl != address(0), "Not implemented");
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 {
                revert(ptr, size)
            }
            default {
                return(ptr, size)
            }
        }
    }

    receive() external payable {
        // Todo: If desired, implement logic to allow receiving funds from specific addresses.
        // Todo: Make sure to revert when deploying to production.
        // revert("Receive not allowed without function call");
    }
}
