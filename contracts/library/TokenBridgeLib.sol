// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./BridgeLib.sol";
import "./StorageTypes.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TokenBridgeLib {
    /**
     * @dev Transfers tokens from the calling contract to the provided recipient and returns a boolean value regarding
     * its success.
     * @param _token The address of the token on the Neo X network.
     * @param _to The address of the recipient.
     * @param _amount The amount to transfer.
     */
    function _safeERC20Transfer(IERC20 _token, address _to, uint256 _amount) internal returns (bool) {
        return _callOptionalReturnBool(_token, abi.encodeCall(_token.transfer, (_to, _amount)));
    }

    /**
     * This function has been copied from the OpenZeppelin SafeERC20.sol library.
     *
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
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
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 parent = _previousRoot;
        uint256 depositsLength = _deposits.length;
        for (uint256 i = 0; i < depositsLength; i++) {
            BridgeLib.DepositData calldata depositData = _deposits[i];
            bytes32 depositHash =
                _hashTokenBridgeOp(_neoN3Token, _neoXToken, depositData.nonce, depositData.to, depositData.amount);
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
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_neoN3Token, _neoXToken, _nonce, _to, _value));
    }

    /**
     * @dev Validates the token configuration.
     * @param _config The token configuration.
     */
    function _isValidConfig(StorageTypes.TokenConfig memory _config) internal pure returns (bool) {
        // The fee must always be greater than 0.
        return _config.neoN3Token != address(0) && _config.fee > 0 && _config.minAmount > 0
            && _config.maxAmount > _config.minAmount && _config.maxDeposits > 0 && _config.decimalScalingFactor >= 0
            && _config.decimalScalingFactor <= MAX_DECIMAL_DIFFERENCE;
    }

    // The maximum difference in decimal precision between the two tokens on both chains. The bridge contract on N3 enforces a maximum transfer amount of 10^41. Together with this value, the maximum amount that can be used in a transfer is 10^77, protecting from any potential overflow.
    uint256 constant MAX_DECIMAL_DIFFERENCE = 36;
}
