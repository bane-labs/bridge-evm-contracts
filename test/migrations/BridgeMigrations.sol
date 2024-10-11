// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {TestBridge, BridgeImpl} from "../../contracts/tests/TestBridge.sol";
import "../../contracts/tests/interfaces/ITestBridgeManagement.sol";
import {BridgeImplV1ToV2} from "../../contracts/bridge/BridgeImplV1ToV2.sol";

library BridgeMigrations {
    function deployBridgeV1ToV2(
        address _managementProxyAddress,
        Options memory opts
    ) internal returns (address) {
        ITestBridgeManagement management = ITestBridgeManagement(
            _managementProxyAddress
        );
        address owner = management.owner();
        address bridgeV1 = deployBridgeV1(_managementProxyAddress, opts);
        migrateBridgeV1ToV2(
            bridgeV1,
            owner,
            new BridgeImplV1ToV2.TokenMigrationV1[](0)
        );
        return bridgeV1;
    }

    function deployBridgeV1ToV2WithTokenMigration(
        address _managementProxyAddress,
        Options memory opts,
        BridgeImplV1ToV2.TokenMigrationV1[] memory tokenMigrationsV1ToV2
    ) internal returns (address) {
        address bridgeV1 = deployBridgeV1(_managementProxyAddress, opts);
        ITestBridgeManagement management = ITestBridgeManagement(
            _managementProxyAddress
        );
        address owner = management.owner();
        migrateBridgeV1ToV2(bridgeV1, owner, tokenMigrationsV1ToV2);
        return bridgeV1;
    }

    function deployBridgeV1(
        address _managementProxyAddress,
        Options memory opts
    ) private returns (address) {
        return
            Upgrades.deployUUPSProxy(
                "TestBridge.sol",
                abi.encodeCall(
                    TestBridge.initialize,
                    (_managementProxyAddress, 1e17, 1e18, 1e22, 100)
                ),
                opts
            );
    }

    function migrateBridgeV1ToV2(
        address proxy,
        address owner,
        BridgeImplV1ToV2.TokenMigrationV1[] memory tokenMigrationsV1ToV2
    ) private {
        bytes memory migrationCall = abi.encodeCall(
            BridgeImplV1ToV2.upgradeToV2,
            (tokenMigrationsV1ToV2)
        );
        Upgrades.upgradeProxy(
            proxy,
            "TestBridgeV1ToV2.sol",
            migrationCall,
            owner
        );
    }
}
