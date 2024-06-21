// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeManagementStorage.sol";
import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";

/**
 * When generating the bytecode for genesis script:
 * - set initial storage values in BridgeManagementStorage.sol
 */
contract BridgeManagementImpl is BridgeManagementStorage, IBridgeManagement {
    constructor() BridgeManagementStorage() {}

    function verifyValidatorSignatures(
        bytes32 _newDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    ) external view returns (bool) {
        uint8 threshold = validatorThreshold;
        if (_signatures.length != threshold) {
            return false;
        }
        bytes32 signedRootMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_newDepositRoot))
            )
        );
        address[] memory recovered = new address[](threshold);
        for (uint i = 0; i < threshold; i++) {
            BridgeLib.Signature calldata sig = _signatures[i];
            recovered[i] = ecrecover(signedRootMsg, sig.v, sig.r, sig.s);
        }
        // check if all recovered addresses are in the validator set
        uint covered = 0;
        uint n = 0;
        uint j;
        uint validatorsLength = validators.length;
        for (uint i = 0; i < threshold; i++) {
            for (j = n; j < validatorsLength; j++) {
                if (recovered[i] == validators[j]) {
                    covered++;
                    break;
                }
            }
            n = j + 1;
        }
        return covered == threshold;
    }

    function setOwner(address _owner) external onlyOwner {
        _setOwner(_owner);
        emit OwnerChange(_owner);
    }

    function getOwner() external view override returns (address) {
        return owner;
    }

    function setRelayer(address _relayer) external onlyOwner {
        _setRelayer(_relayer);
        emit RelayerChange(_relayer);
    }

    function getRelayer() external view override returns (address) {
        return relayer;
    }

    function setValidators(
        address[] calldata _validators,
        uint threshold
    ) external onlyOwner {
        _setValidators(_validators, threshold);
        emit ValidatorsChange(_validators, threshold);
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function getValidator(uint _index) external view returns (address) {
        return validators[_index];
    }

    function getValidatorThreshold() external view returns (uint) {
        return validatorThreshold;
    }

    function setGovernor(address _governor) external onlyOwner {
        _setGovernor(_governor);
        emit GovernorChange(_governor);
    }

    function getGovernor() external view override returns (address) {
        return governor;
    }

    function setSecurityGuard(address _securityGuard) external onlyOwner {
        _setSecurityGuard(_securityGuard);
        emit SecurityGuardChange(_securityGuard);
    }

    function getSecurityGuard() external view override returns (address) {
        return securityGuard;
    }

    function setFunder(address _funder) external onlyOwner {
        _setFunder(_funder);
        emit FunderChange(_funder);
    }

    function getFunder() external view override returns (address) {
        return funder;
    }
}
