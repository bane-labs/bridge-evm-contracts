// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library ManagementLib {
    function _hasDuplicates(
        address[] memory _addresses
    ) internal pure returns (bool) {
        uint256 addressesLength = _addresses.length;
        for (uint256 i = 0; i < addressesLength - 1; i++) {
            for (uint256 j = i + 1; j < addressesLength; j++) {
                if (_addresses[i] == _addresses[j]) {
                    return true;
                }
            }
        }
        return false;
    }
}
