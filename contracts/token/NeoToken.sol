// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NeoToken is Initializable, ERC20Upgradeable, Ownable2StepUpgradeable, UUPSUpgradeable {
    uint256 constant MAX_SUPPLY = 1e26;

    error MaxSupplyExceeded();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("NeoToken", "NEO");
        __Ownable_init(0x0F378b9433c674Bc5021908b7a4150C6B0C3704E);
        __UUPSUpgradeable_init();
    }

    // Todo: Consider hard-coding the to parameter to the bridge proxy (or a separate treasury contract that the bridge contract can access)
    function mint(address to, uint256 amount) public onlyOwner {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert MaxSupplyExceeded();
        }
        _mint(to, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
