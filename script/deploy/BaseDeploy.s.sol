// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script, stdJson} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestBridgeManagement} from "../../contracts/tests/TestBridgeManagement.sol";
import {TestBridge} from "../../contracts/tests/TestBridge.sol";
import {TestMessageBridge} from "../../contracts/tests/TestMessageBridge.sol";
import {ExecutionManager} from "../../contracts/messageBridge/ExecutionManager.sol";

/// @title BaseDeploy
/// @notice Shared manifest, environment parsing, deployment, and logging helpers for Foundry deploy scripts.
/// @dev Concrete deploy scripts use the manifest to pass deployed addresses between
/// one-by-one deployments. The full-suite script uses the same helpers to keep the
/// single-command deployment path behaviorally aligned with the individual scripts.
abstract contract BaseDeploy is Script {
    using stdJson for string;

    struct Roles {
        address owner;
        address relayer;
        uint256 validatorThreshold;
        address[] validators;
        address governor;
        address securityGuard;
        address funder;
    }

    struct MessageBridgeConfig {
        uint256 fee;
        uint256 maxMessageSize;
        uint256 maxNrMessages;
        uint256 executionWindowSeconds;
    }

    struct DeploymentManifest {
        address bridgeManagement;
        address bridgeManagementImplementation;
        address bridge;
        address bridgeImplementation;
        address messageBridge;
        address messageBridgeImplementation;
        address executionManager;
    }

    string internal constant DEFAULT_MANIFEST_DIR = "deployments/foundry";

    function _deploymentNetwork() internal view returns (string memory) {
        if (vm.envExists("DEPLOYMENT_NETWORK")) return vm.envString("DEPLOYMENT_NETWORK");
        return vm.toString(block.chainid);
    }

    function _manifestDir() internal view returns (string memory) {
        if (vm.envExists("DEPLOYMENT_MANIFEST_DIR")) return vm.envString("DEPLOYMENT_MANIFEST_DIR");
        return DEFAULT_MANIFEST_DIR;
    }

    function _manifestPath() internal view returns (string memory) {
        if (vm.envExists("DEPLOYMENT_MANIFEST")) return vm.envString("DEPLOYMENT_MANIFEST");
        return string.concat(_manifestDir(), "/", _deploymentNetwork(), ".json");
    }

    function _roles() internal view returns (Roles memory roles) {
        roles.owner = _requiredAddress("BRIDGE_OWNER");
        roles.relayer = _requiredAddress("BRIDGE_RELAYER");
        roles.validatorThreshold = _envUintOr("BRIDGE_VALIDATOR_THRESHOLD", 2);
        roles.validators = new address[](2);
        roles.validators[0] = _requiredAddress("BRIDGE_VALIDATOR01");
        roles.validators[1] = _requiredAddress("BRIDGE_VALIDATOR02");
        roles.governor = _requiredAddress("BRIDGE_GOVERNOR");
        roles.securityGuard = _envAddressOr("BRIDGE_SECURITY_GUARD", roles.owner);
        roles.funder = _envAddressOr("BRIDGE_FUNDER", roles.owner);
    }

    function _messageBridgeConfig() internal view returns (MessageBridgeConfig memory config) {
        config.fee = _envUintOr("MESSAGE_BRIDGE_FEE", 0.1 ether);
        config.maxMessageSize = _envUintOr("MESSAGE_BRIDGE_MAX_MESSAGE_SIZE", 10_240);
        config.maxNrMessages = _envUintOr("MESSAGE_BRIDGE_MAX_NR_MESSAGES", 100);
        config.executionWindowSeconds = _envUintOr("MESSAGE_BRIDGE_EXECUTION_WINDOW_SECONDS", 1 days);
    }

    function _deployBridgeManagement(Roles memory roles)
        internal
        returns (TestBridgeManagement management, address implementation)
    {
        implementation = address(new TestBridgeManagement());
        bytes memory initData = abi.encodeCall(
            TestBridgeManagement.initialize,
            (
                roles.owner,
                roles.relayer,
                roles.validatorThreshold,
                roles.validators,
                roles.governor,
                roles.securityGuard,
                roles.funder
            )
        );
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        management = TestBridgeManagement(payable(address(proxy)));
        require(management.getCurrentInitializedVersion() == 3, "BridgeManagement initialization failed");
    }

    function _deployBridge(address managementAddress) internal returns (TestBridge bridge, address implementation) {
        require(managementAddress != address(0), "BridgeManagement missing");
        implementation = address(new TestBridge());
        ERC1967Proxy proxy =
            new ERC1967Proxy(implementation, abi.encodeCall(TestBridge.initialize, (managementAddress)));
        bridge = TestBridge(payable(address(proxy)));
        require(address(bridge.management()) == managementAddress, "Bridge management mismatch");
        require(bridge.getCurrentInitializedVersion() == 3, "Bridge initialization failed");
    }

    function _deployMessageBridge(
        address managementAddress,
        MessageBridgeConfig memory config
    )
        internal
        returns (TestMessageBridge messageBridge, address implementation)
    {
        require(managementAddress != address(0), "BridgeManagement missing");
        implementation = address(new TestMessageBridge());
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementation,
            abi.encodeCall(
                TestMessageBridge.initialize,
                (
                    managementAddress,
                    config.fee,
                    config.maxMessageSize,
                    config.maxNrMessages,
                    config.executionWindowSeconds
                )
            )
        );
        messageBridge = TestMessageBridge(payable(address(proxy)));
        require(address(messageBridge.management()) == managementAddress, "MessageBridge management mismatch");
    }

    function _deployExecutionManager(address messageBridgeAddress)
        internal
        returns (ExecutionManager executionManager)
    {
        require(messageBridgeAddress != address(0), "MessageBridge missing");
        executionManager = new ExecutionManager(messageBridgeAddress);
        require(
            executionManager.hasRole(executionManager.BRIDGE_ROLE(), messageBridgeAddress), "MessageBridge role missing"
        );
    }

    function _loadManifest() internal returns (DeploymentManifest memory manifest) {
        string memory path = _manifestPath();
        if (!vm.exists(path)) return manifest;

        string memory json = vm.readFile(path);
        manifest.bridgeManagement = _readAddressOrZero(json, ".contracts.bridgeManagement");
        manifest.bridgeManagementImplementation = _readAddressOrZero(json, ".contracts.bridgeManagementImplementation");
        manifest.bridge = _readAddressOrZero(json, ".contracts.bridge");
        manifest.bridgeImplementation = _readAddressOrZero(json, ".contracts.bridgeImplementation");
        manifest.messageBridge = _readAddressOrZero(json, ".contracts.messageBridge");
        manifest.messageBridgeImplementation = _readAddressOrZero(json, ".contracts.messageBridgeImplementation");
        manifest.executionManager = _readAddressOrZero(json, ".contracts.executionManager");
    }

    function _writeManifest(DeploymentManifest memory manifest) internal {
        string memory path = _manifestPath();
        vm.createDir(_manifestDir(), true);

        string memory json = string.concat(
            "{\n",
            '  "network": "',
            _deploymentNetwork(),
            '",\n',
            '  "chainId": ',
            vm.toString(block.chainid),
            ",\n",
            '  "contracts": {\n',
            '    "bridgeManagement": "',
            vm.toString(manifest.bridgeManagement),
            '",\n',
            '    "bridgeManagementImplementation": "',
            vm.toString(manifest.bridgeManagementImplementation),
            '",\n',
            '    "bridge": "',
            vm.toString(manifest.bridge),
            '",\n',
            '    "bridgeImplementation": "',
            vm.toString(manifest.bridgeImplementation),
            '",\n',
            '    "messageBridge": "',
            vm.toString(manifest.messageBridge),
            '",\n',
            '    "messageBridgeImplementation": "',
            vm.toString(manifest.messageBridgeImplementation),
            '",\n',
            '    "executionManager": "',
            vm.toString(manifest.executionManager),
            '"\n',
            "  }\n",
            "}\n"
        );

        vm.writeFile(path, json);
        console2.log("Deployment manifest:", path);
    }

    function _printBridgeManagement(TestBridgeManagement management, address implementation) internal view {
        console2.log("");
        console2.log("Deployment of BridgeManagement");
        console2.log("BridgeManagement Proxy: ", address(management));
        console2.log("BridgeManagement Logic: ", implementation);
        console2.log("");
        console2.log("Roles");
        console2.log("Owner:               ", management.owner());
        console2.log("Relayer:             ", management.getRelayer());
        console2.log("Validator Threshold: ", management.getValidatorThreshold());
        address[] memory validators = management.getValidators();
        for (uint256 i = 0; i < validators.length; i++) {
            console2.log(string.concat("Validator ", vm.toString(i + 1), ":         "), validators[i]);
        }
        console2.log("Governor:            ", management.getGovernor());
        console2.log("Security Guard:      ", management.getSecurityGuard());
        console2.log("Funder:              ", management.getFunder());
    }

    function _printBridge(TestBridge bridge, address implementation) internal view {
        console2.log("");
        console2.log("Deployment of Bridge");
        console2.log("Bridge Proxy: ", address(bridge));
        console2.log("Bridge Logic: ", implementation);
        console2.log("");
        console2.log("Bridge Configuration");
        console2.log("Linked Management:          ", address(bridge.management()));
    }

    function _printMessageBridge(TestMessageBridge messageBridge, address implementation) internal view {
        console2.log("");
        console2.log("Deployment of MessageBridge");
        console2.log("MessageBridge Proxy: ", address(messageBridge));
        console2.log("MessageBridge Logic: ", implementation);
        console2.log("");
        console2.log("MessageBridge Configuration");
        console2.log("Management Contract:             ", address(messageBridge.management()));
        console2.log("MessageBridge Paused:            ", messageBridge.messageBridgePaused());
        console2.log("MessageBridge Sending Paused:    ", messageBridge.sendingPaused());
        console2.log("MessageBridge Executing Paused:  ", messageBridge.executingPaused());
        console2.log("MessageBridge Sending Fee:       ", messageBridge.sendingFee());
        console2.log("MessageBridge Max Msg Size:      ", messageBridge.maxMessageSize());
        console2.log("MessageBridge Max Nr Messages:   ", messageBridge.maxNrMessages());
        console2.log("MessageBridge Execution Window:  ", messageBridge.executionWindowSeconds());
    }

    function _printExecutionManager(ExecutionManager executionManager) internal pure {
        console2.log("");
        console2.log("Deployment of ExecutionManager");
        console2.log("Execution Manager: ", address(executionManager));
    }

    function _readAddressOrZero(string memory json, string memory key) private view returns (address) {
        if (!vm.keyExistsJson(json, key)) return address(0);
        return json.readAddress(key);
    }

    function _requiredAddress(string memory name) private view returns (address) {
        require(vm.envExists(name), string.concat("Missing required env var: ", name));
        address value = vm.envAddress(name);
        require(value != address(0), string.concat("Zero address env var: ", name));
        return value;
    }

    function _envAddressOr(string memory name, address fallbackValue) private view returns (address) {
        if (!vm.envExists(name)) return fallbackValue;
        address value = vm.envAddress(name);
        require(value != address(0), string.concat("Zero address env var: ", name));
        return value;
    }

    function _envUintOr(string memory name, uint256 fallbackValue) private view returns (uint256) {
        if (!vm.envExists(name)) return fallbackValue;
        return vm.envUint(name);
    }
}
