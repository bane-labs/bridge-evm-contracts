// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeManagementStorage.sol";
import "../interfaces/IBridgeManagement.sol";
import "../library/BridgeLib.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract BridgeManagementImpl is BridgeManagementStorage, IBridgeManagement {
    function initialize(
        address _owner,
        address _relayer,
        uint256 _validatorThreshold,
        address[] memory _validators,
        address _governor,
        address _securityGuard,
        address _funder
    ) public initializer {
        __Ownable_init(_owner);
        _setRelayer(_relayer);
        _setValidators(_validators, _validatorThreshold);
        _setGovernor(_governor);
        _setSecurityGuard(_securityGuard);
        _setFunder(_funder);
    }

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
        bytes32 signedRootMsg = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_newDepositRoot))
            )
        );
        address[] memory recovered = new address[](threshold);
        for (uint256 i = 0; i < threshold; i++) {
            BridgeLib.Signature calldata sig = _signatures[i];
            recovered[i] = ECDSA.recover(signedRootMsg, sig.v, sig.r, sig.s);
        }
        // check if all recovered addresses are in the validator set
        uint256 covered = 0;
        uint256 n = 0;
        uint256 j;
        uint256 validatorsLength = validators.length;
        for (uint256 i = 0; i < threshold; i++) {
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
