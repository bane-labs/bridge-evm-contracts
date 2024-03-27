// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BridgeManagementContract.sol";
import "./TestBridgeStorageV1.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// This test just contains dummy data to test the upgradeability.

contract TestBridgeStorageV2 is TestBridgeStorageV1 {
    mapping(address => bool) public isRegistered;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function register(address _token) external {
        isRegistered[_token] = true;
    }

    function _setGasWithdrawalFee(uint256 _fee) internal override {
        require(_fee >= 10 ** 18, "Fee must be at least 1 gas");
        require(
            (_fee % (10 ** 10)) == 0,
            "Fee must have maximally 8 non-zero decimals"
        );
        gasBridge.config.fee = _fee;
    }
}
