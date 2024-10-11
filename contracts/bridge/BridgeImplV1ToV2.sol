// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeImpl.sol";

contract BridgeImplV1ToV2 is BridgeImpl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() BridgeImpl() {}

    struct TokenMigrationV1 {
        address token;
        uint256 decimalScalingFactor;
    }

    function upgradeToV2(
        TokenMigrationV1[] calldata _tokenBridgeMigrations
    ) external virtual reinitializer(2) onlyAdmin {
        _upgradeToV2(_tokenBridgeMigrations);
    }

    function _upgradeToV2(
        TokenMigrationV1[] calldata _tokenBridgeMigrations
    ) internal onlyInitializing {
        for (uint256 i = 0; i < _tokenBridgeMigrations.length; i++) {
            TokenMigrationV1 memory migration = _tokenBridgeMigrations[i];
            if (!_isRegisteredToken(migration.token))
                revert("Token not registered");
            StorageTypes.TokenConfig storage config = tokenBridges[
                migration.token
            ].config;
            config.decimalScalingFactor = migration.decimalScalingFactor;
        }
    }
}
