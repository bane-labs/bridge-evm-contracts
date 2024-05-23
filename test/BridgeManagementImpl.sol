pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../contracts/BridgeManagementImpl.sol";
contract BridgeManagementImplTest is Test {
    BridgeManagementImpl bridgeManagementImpl;
    address public owner = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    function setUp() public {
        bridgeManagementImpl = new BridgeManagementImpl();
    }

    function testSetOwner() public {
        assertEq(bridgeManagementImpl.getOwner(), owner);
        vm.prank(owner);
        bridgeManagementImpl.setOwner(user);
        assertEq(bridgeManagementImpl.getOwner(), user);
    }
}