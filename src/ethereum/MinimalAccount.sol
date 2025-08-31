// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IAccount} from "@eth-infinitism/account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@eth-infinitism/account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";

/**
 * @title Minimal Account
 * @author Alexander Scherbatyuk
 * @notice Account Abstraction
 * @dev A signature  is valid, if it's the Minimal Account owner
 */
contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

    modifier requireFormEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute a call to a destination contract
     * @param dest The destination address
     * @param value The value to send
     * @param functionData The function data to execute
     */
    function execute(address dest, uint256 value, bytes calldata functionData) external requireFormEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    /**
     * @dev Validate the user operation
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     * @param missingAccountFunds The missing account funds
     * @return validationData The validation data
     * @dev This function is called by the entry point to validate the user operation
     * @dev Main function that allow EntryPoint to execute the user operations, or reject them
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        // struct PackedUserOperation {
        //     address sender;                  // our minimal account
        //     uint256 nonce;                   // nonce
        //     bytes initCode;                  // ignore for now
        //     bytes callData;                  // this is where we put "the good stuff". Our minnimal account approve USDC for 50 tokens
        //     bytes32 accountGasLimits;        // gas limit
        //     uint256 preVerificationGas;      // gas
        //     bytes32 gasFees;                 // gas
        //     bytes paymasterAndData;
        //     bytes signature;
        // }

        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validate the signature of the user operation
     * @dev EIP-191 version of the signature hash
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     * @return validationData The validation data
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
