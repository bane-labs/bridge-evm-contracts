// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library ManagementLib {
    function _hasDuplicates(
        address[] memory _addresses
    ) internal pure returns (bool) {
        uint addressesLength = _addresses.length;
        for (uint i = 0; i < addressesLength - 1; i++) {
            for (uint j = i + 1; j < addressesLength; j++) {
                if (_addresses[i] == _addresses[j]) {
                    return true;
                }
            }
        }
        return false;
    }
}
