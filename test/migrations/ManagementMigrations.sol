// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeImplV1ToV2} from "../../contracts/bridge/BridgeImplV1ToV2.sol";
import {TestBridgeManagement} from "../../contracts/tests/TestBridgeManagement.sol";
import {TestManagementV1ToV2} from "../../contracts/tests/migrations/TestManagementV1ToV2.sol";
import {ITestBridgeManagement} from "../../contracts/tests/interfaces/ITestBridgeManagement.sol";

library ManagementMigrations {
    function deployManagementV1ToV2(
        address owner,
        address relayer,
        uint256 validatorThreshold,
        address[] memory validatorsAddresses,
        address governor,
        address securityGuard,
        address funder,
        Options memory opts
    ) internal returns (address) {
        address managementProxyAddress = _deployManagementV1(
            owner,
            relayer,
            validatorThreshold,
            validatorsAddresses,
            governor,
            securityGuard,
            funder,
            opts
        );
        _migrateManagementV1ToV2(managementProxyAddress, owner);
        return managementProxyAddress;
    }

    function _deployManagementV1(
        address owner,
        address relayer,
        uint256 validatorThreshold,
        address[] memory validatorsAddresses,
        address governor,
        address securityGuard,
        address funder,
        Options memory opts
    ) private returns (address) {
        return
            Upgrades.deployUUPSProxy(
                "TestBridgeManagement.sol",
                abi.encodeCall(
                    TestBridgeManagement.initialize,
                    (
                        owner,
                        relayer,
                        validatorThreshold,
                        validatorsAddresses,
                        governor,
                        securityGuard,
                        funder
                    )
                ),
                opts
            );
    }

    function _migrateManagementV1ToV2(address proxy, address owner) private {
        bytes memory migrationCall = abi.encodeCall(
            TestManagementV1ToV2.upgradeToV2,
            ()
        );
        Upgrades.upgradeProxy(
            proxy,
            "TestManagementV1ToV2.sol",
            migrationCall,
            owner
        );
    }
}
