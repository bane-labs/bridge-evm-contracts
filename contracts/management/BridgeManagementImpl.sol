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

    function setValidators(
        address[] calldata _validators,
        uint256 threshold
    ) external onlyOwner {
        _setValidators(_validators, threshold);
        emit ValidatorsChange(_validators, threshold);
    }

    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    function getValidator(uint256 _index) external view returns (address) {
        return validators[_index];
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
