// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "../management/BridgeManagementImpl.sol";

contract TestBridgeManagement is BridgeManagementImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeManagementImpl() {}

    function initialize(
        address _owner,
        address _relayer,
        uint256 _validatorThreshold,
        address[] calldata _validators,
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

    // Authorize the contract owner to upgrade the contract for testing purposes.
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}
