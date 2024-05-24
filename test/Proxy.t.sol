pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../contracts/bridge/BridgeImpl.sol";
import "../contracts/tests/SigUtils.sol";
import "../contracts/library/BridgeLib.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";


contract ProxyTest is Test {
BridgeImpl public brideImpl;
ERC1967Proxy public proxy;

    function setUp() public {
        brideImpl = new BridgeImpl(0xBcd4042DE499D14e55001CcbB24a551F3b954096);
        proxy = new ERC1967Proxy(address(brideImpl),"");
    }
    function testInitialize() public {
       address m =  address(BridgeImpl(payable(address(proxy))).management());
       assertEq(m, 0xBcd4042DE499D14e55001CcbB24a551F3b954096);

    }
 }

