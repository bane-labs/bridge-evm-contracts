// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../library/BridgeLib.sol";

interface IBridgeManagement {
    event OwnerChange(address owner);
    event RelayerChange(address relayer);
    event ValidatorsChange(address[] validators, uint threshold);
    event GovernorChange(address governor);
    event SecurityGuardChange(address securityGuard);
    event FunderChange(address funder);

    function getOwner() external view returns (address);

    function setRelayer(address _relayer) external;

    function getRelayer() external view returns (address);

    function setValidators(
        address[] calldata _validators,
        uint threshold
    ) external;

    function getValidators() external view returns (address[] memory);

    function getValidator(uint _index) external view returns (address);

    function getValidatorThreshold() external view returns (uint);

    function verifyValidatorSignatures(
        bytes32 _newDepositRoot,
        BridgeLib.Signature[] calldata _signatures
    ) external view returns (bool);

    function setGovernor(address _governor) external;

    function getGovernor() external view returns (address);

    function setSecurityGuard(address _securityGuard) external;

    function getSecurityGuard() external view returns (address);

    function setFunder(address _funder) external;

    function getFunder() external view returns (address);
}
