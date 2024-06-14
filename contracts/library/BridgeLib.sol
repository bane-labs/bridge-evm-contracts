// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library BridgeLib {
    struct DepositData {
        uint256 nonce;
        address payable to;
        uint256 amount;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Makes sure the proofs have subsequent nonces.
    function _subsequentNonces(
        DepositData[] calldata _deposits,
        uint256 _startNonce
    ) internal pure returns (bool) {
        uint depositsLength = _deposits.length;
        for (uint8 i = 1; i <= depositsLength; i++) {
            if (_deposits[i - 1].nonce != _startNonce + i) {
                return false;
            }
        }
        return true;
    }

    function _computeNewRoot(
        bytes32 _formerRoot,
        bytes32 _depositHash
    ) internal pure returns (bytes32) {
        return sha256(abi.encodePacked(_formerRoot, _depositHash));
    }

    function _isContract(address _addr) internal view returns (bool) {
        return _addr.code.length > 0;
    }

    /**
     * @dev Checks if a parameter change initialization is allowed. A parameter change initialization is allowed if there's no active change in storage (i.e., if its current pending value is 0), or if its pendingUntilBlock value has exceeded the block number by at least 1 block (providing at least 1 block in which the current change could be executed before it can be overwritten).
     * @param _currentPendingUntilBlock the pendingUntilBlock of the current change in storage.
     * @param _blockNumber the current block number.
     */
    function _paramChangeInitAllowed(
        uint256 _currentPendingUntilBlock,
        uint256 _blockNumber
    ) internal pure returns (bool) {
        return
            _currentPendingUntilBlock == 0 ||
            _blockNumber > _currentPendingUntilBlock + 1;
    }
}
