// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./BridgeManagementStorage.sol";
import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";

using EnumerableSet for EnumerableSet.AddressSet;

contract BridgeManagementImpl is BridgeManagementStorage, IBridgeManagement {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function verifyValidatorSignatures(
        bytes32 _newDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    )
        external
        view
        returns (bool)
    {
        uint256 threshold = validatorThreshold;
        if (_signatures.length != threshold) return false;
        // Create the message to be signed
        bytes32 signedRootMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(block.chainid, _newDepositRoot))
            )
        );
        // Recover the signing addresses and make sure there are no duplicates
        address[] memory recovered = new address[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            BridgeLib.Signature calldata sig = _signatures[i];
            recovered[i] = ECDSA.recover(signedRootMsg, sig.v, sig.r, sig.s);
            // If one of the provided signatures is not from a validator, return false
            if (!_isValidator(recovered[i])) return false;
        }
        if (ManagementLib._hasDuplicates(recovered)) return false;
        return true;
    }

    function setRelayer(address _relayer) external onlyOwner {
        _setRelayer(_relayer);
        emit RelayerChange(_relayer);
    }

    function getRelayer() external view override returns (address) {
        return relayer;
    }

    function addValidator(address _validator, bool _incrementThreshold) external onlyOwner {
        _addValidator(_validator);
        emit ValidatorAdd(_validator);
        if (_incrementThreshold) {
            _incrementValidatorThreshold();
            emit ValidatorThresholdChange(validatorThreshold);
        }
    }

    function removeValidator(address _validator, bool _decrementThreshold) external onlyOwner {
        if (_decrementThreshold) {
            _decrementValidatorThreshold();
            emit ValidatorThresholdChange(validatorThreshold);
        }
        _removeValidator(_validator);
        emit ValidatorRemove(_validator);
    }

    function replaceValidator(address _oldValidator, address _newValidator) external onlyOwner {
        _removeValidator(_oldValidator);
        _addValidator(_newValidator);
        emit ValidatorReplace(_oldValidator, _newValidator);
    }

    function isValidator(address _validator) external view returns (bool) {
        return _isValidator(_validator);
    }

    function getValidators() external view returns (address[] memory) {
        return validatorSet.values();
    }

    function setValidatorThreshold(uint256 _threshold) external onlyOwner {
        _setValidatorThreshold(_threshold);
        emit ValidatorThresholdChange(_threshold);
    }

    function getValidatorThreshold() external view returns (uint256) {
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

    // Migration functionality v.1.0.0 to v.2.0.0

    function upgradeToV2() external virtual reinitializer(2) onlyAdmin {
        _upgradeToV2();
    }
}
