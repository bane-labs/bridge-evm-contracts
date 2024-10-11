// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeManagementStorage.sol";
import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BridgeManagementImpl is BridgeManagementStorage, IBridgeManagement {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function verifyValidatorSignatures(
        bytes32 _newDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    ) external view returns (bool) {
        uint256 threshold = validatorThreshold;
        if (_signatures.length != threshold) {
            return false;
        }
        // Create the message to be signed
        bytes32 signedRootMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(block.chainid, _newDepositRoot))
            )
        );
        // Recover the signing addresses and make sure there are no duplicates
        address[] memory recovered = new address[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            BridgeLib.Signature calldata sig = _signatures[i];
            recovered[i] = ECDSA.recover(signedRootMsg, sig.v, sig.r, sig.s);
            // If one of the provided signatures is not from a validator, return false
            if (!validatorMap[recovered[i]]) return false;
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

    function isValidator(address _validator) external view returns (bool) {
        return _isValidator(_validator);
    }

    function addValidator(
        address _validator,
        bool _increaseThreshold
    ) external onlyOwner {
        _addValidator(_validator, _increaseThreshold);
        emit ValidatorAdd(_validator, _increaseThreshold);
    }

    function removeValidator(
        uint256 _index,
        address _validator,
        bool _decreaseThreshold
    ) external onlyOwner {
        _removeValidator(_index, _validator, _decreaseThreshold);
        emit ValidatorRemove(_validator, _decreaseThreshold);
    }

    function replaceValidator(
        uint256 _index,
        address _oldValidator,
        address _newValidator
    ) external onlyOwner {
        _replaceValidator(_index, _oldValidator, _newValidator);
        emit ValidatorReplace(_oldValidator, _newValidator);
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
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
}
