// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../BridgeManagementContract.sol";
import "./TestBridgeStorageV1.sol";

// This test just contains dummy data to test the upgradeability.

contract TestUpgradeBridgeStorage is BridgeStorageV1 {
    mapping(address => bool) public isRegistered;

    function _register(address _token) internal {
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
