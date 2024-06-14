// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BridgeLib.sol";
import "./StorageTypes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TokenBridgeLib {
    /**
     * @dev Executes the transfer of the token on the Neo N3 network.
     * @param _neoXToken The address of the token on the Neo X network.
     * @param _amount The amount to transfer.
     * @param _to The address of the recipient.
     */
    function _executeERC20Transfer(
        address _neoXToken,
        uint256 _amount,
        address _to
    ) internal returns (bool) {
        bytes memory transferCall = abi.encodeCall(
            IERC20.transfer,
            (_to, _amount)
        );
        (bool success, bytes memory returndata) = address(_neoXToken).call(
            transferCall
        );
        return
            success &&
            (returndata.length == 0 || abi.decode(returndata, (bool)));
    }

    /**
     * @dev Hashes every deposit operation and chains it to the previous root. Each deposit data is prepended the
     * token's Neo N3 and Neo X address before it is hashed, such that each token-pair's hash chain remains exclusive
     * to its corresponding chain and to restrict any replay attack vectors. The final top root is returned.
     *
     * @param _previousRoot the previous top root.
     * @param _neoN3Token the address of the token on the Neo N3 network.
     * @param _neoXToken the address of the token on the Neo X network.
     * @param _deposits the deposits' data to be hashed and chained.
     */
    function _computeNewTopRoot(
        bytes32 _previousRoot,
        address _neoN3Token,
        address _neoXToken,
        BridgeLib.DepositData[] calldata _deposits
    ) internal pure returns (bytes32) {
        bytes32 parent = _previousRoot;
        uint depositsLength = _deposits.length;
        for (uint i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash = _hashTokenBridgeOp(
                _neoN3Token,
                _neoXToken,
                depositData.nonce,
                depositData.to,
                depositData.amount
            );
            parent = BridgeLib._computeNewRoot(parent, depositHash);
        }
        return parent;
    }

    /**
     * @dev Hashes the token bridge operation.
     *
     * @param _neoN3Token The address of the token on the Neo N3 network.
     * @param _neoXToken The address of the token on the Neo X network.
     * @param _nonce The nonce of the operation.
     * @param _value The value of the operation.
     * @param _to The address of the recipient.
     */
    function _hashTokenBridgeOp(
        address _neoN3Token,
        address _neoXToken,
        uint256 _nonce,
        address _to,
        uint256 _value
    ) internal pure returns (bytes32) {
        return
            sha256(
                abi.encodePacked(_neoN3Token, _neoXToken, _nonce, _to, _value)
            );
    }

    /**
     * @dev Validates the token configuration.
     * @param _config The token configuration.
     */
    function _isValidConfig(
        StorageTypes.TokenConfig memory _config
    ) internal pure returns (bool) {
        // The fee must always be greater than 0.
        return
            _config.fee > 0 &&
            _config.minAmount > 0 &&
            _config.maxAmount > _config.minAmount &&
            _config.maxDeposits > 0;
    }

    /**
     * @dev Checks if the current change entry is executable. The change is executable if the current block number is greater than its pendingUntilBlock and less than or equal to the executableUntilBlock.
     * @param _change The current change.
     * @param _blockNumber the current block number.
     */
    function _tokenParamChangeIsExecutable(
        StorageTypes.Change memory _change,
        uint _blockNumber
    ) internal pure returns (bool) {
        return
            _blockNumber > _change.pendingUntilBlock &&
            _blockNumber <= _change.executableUntilBlock;
    }
}
