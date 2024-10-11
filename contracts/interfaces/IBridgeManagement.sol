// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../library/BridgeLib.sol";

interface IBridgeManagement {
    event OwnerChange(address owner);
    event RelayerChange(address relayer);
    event ValidatorAdd(address validator, bool thresholdIncreased);
    event ValidatorRemove(address validator, bool thresholdDecreased);
    event ValidatorReplace(address oldValidator, address newValidator);
    event ValidatorThresholdChange(uint256 threshold);
    event GovernorChange(address governor);
    event SecurityGuardChange(address securityGuard);
    event FunderChange(address funder);

    // Relayer

    function setRelayer(address _relayer) external;

    function getRelayer() external view returns (address);

    // Validators

    function addValidator(address _validator, bool _increaseThreshold) external;

    function removeValidator(
        uint256 _index,
        address _validator,
        bool _decreaseThreshold
    ) external;

    function replaceValidator(
        uint256 _index,
        address _oldValidator,
        address _newValidator
    ) external;

    function setValidatorThreshold(uint256 _threshold) external;

    function getValidators() external view returns (address[] memory);

    function isValidator(address _validator) external view returns (bool);

    function getValidatorThreshold() external view returns (uint256);

    function verifyValidatorSignatures(
        bytes32 _newDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    ) external view returns (bool);

    // Governor

    function setGovernor(address _governor) external;

    function getGovernor() external view returns (address);

    // SecurityGuard

    function setSecurityGuard(address _securityGuard) external;

    function getSecurityGuard() external view returns (address);

    // Funder

    function setFunder(address _funder) external;

    function getFunder() external view returns (address);
}
