// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeManagementStorage.sol";

interface IBridgeManagement {
    event SetOwner(address owner);
    event SetRelayer(address relayer);
    event SetValidators(address[] validators, uint threshold);
    event SetGovernor(address governor);
    event SetSecurityGuard(address securityGuard);

    function setOwner(address _owner) external;

    function setRelayer(address _relayer) external;

    function setValidators(
        address[] calldata _validators,
        uint threshold
    ) external;

    function getValidators() external view returns (address[] memory);

    function setGovernor(address _governor) external;

    function setSecurityGuard(address _securityGuard) external;
}

/**
 * When generating the bytecode for genesis script:
 * - set initial storage values in BridgeManagementStorage.sol
 */
contract BridgeManagementImpl is IBridgeManagement, BridgeManagementStorage {
    function setOwner(address _owner) external onlyOwner {
        _setOwner(_owner);
        emit SetOwner(_owner);
    }

    function setRelayer(address _relayer) external onlyOwner {
        _setRelayer(_relayer);
        emit SetRelayer(_relayer);
    }

    function setValidators(
        address[] calldata _validators,
        uint threshold
    ) external onlyOwner {
        _setValidators(_validators, threshold);
        emit SetValidators(_validators, threshold);
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function setGovernor(address _governor) external onlyOwner {
        _setGovernor(_governor);
        emit SetGovernor(_governor);
    }

    function setSecurityGuard(address _securityGuard) external onlyOwner {
        _setSecurityGuard(_securityGuard);
        emit SetSecurityGuard(_securityGuard);
    }
}
