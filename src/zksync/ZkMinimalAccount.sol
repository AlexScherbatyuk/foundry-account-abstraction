// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {SystemContractsCaller} from
    "@cyfrin/foundry-era-contracts/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/interfaces/INonceHolder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Utils} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/libraries/Utils.sol";

/**
 * Lifecycle of a type 113 (0x71) transaction:
 * msg.sender is bootloader system contract
 *
 * Pahse 1 - Validation
 * 1. The user sends the transaction th the "zkSync API client" (sort of a "light node")
 * 2. The zkSync APIC client checks to see if the nonce is unique by querying the NonceHolder system contract
 * 3. The zkSync API client calls validateTransaction, which MUST update nonce
 * 4. The zkSync API client (node) checks the nonce is updated
 * 5. The zkSync API client calls payForTransaction, or prepareForPaymaster & validateAndPayForPaymasterTransaction
 * 6. The zkSync API client verifies that the bootloader gets paid
 *
 * Phase 2 - Execution
 * 7. The zkSync API client passes the validation transaction to the main node / sequencer
 * 8. The main node calls executeTransaction
 *
 *
 *
 */
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__NotFromBootLoaderOrOwner();
    error ZkMinimalAccount__FailedToPay();
    error ZkMinimalAccount__InvalidSignature();
    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier requireFromBootLoader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
        }
        _;
    }

    modifier requireFromBootLoaderOrOwner() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS && msg.sender != owner()) {
            revert ZkMinimalAccount__NotFromBootLoaderOrOwner();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    receive() external payable {}
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Called by the bootloader to validate that an account agrees to process the transaction
     * (and potentially pay for it).
     * //param _txHash The hash of the transaction to be used in the explorer
     * //param //_suggestedSignedHash The hash of the transaction is signed by EOAs
     * @param _transaction The transaction itself
     * @return magic The magic value that should be equal to the signature of this function
     * if the user agrees to proceed with the transaction.
     * @dev The developer should strive to preserve as many steps as possible both for valid
     * and invalid transactions as this very method is also used during the gas fee estimation
     * (without some of the necessary data, e.g. signature).
     * @dev very simple implementation to EIP-4337 verifyUsvalidateUserOp from ethereum MinimalAccount.sol
     * @dev must increase the nonce
     * @dev must validate the transaction (check the owner signed the transaction)
     * @dev also check to see if we have enought money in our account
     */

    function validateTransaction(
        bytes32, /*_txHash*/
        bytes32, /* _suggestedSignedHash*/
        Transaction memory _transaction
    ) external payable requireFromBootLoader returns (bytes4 magic) {
        return _validateTransaction(_transaction);
    }

    function executeTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
        requireFromBootLoaderOrOwner
    {
        _executeTransaction(_transaction);
    }

    // There is no point in providing possible signed hash in the `executeTransactionFromOutside` method,
    // since it typically should not be trusted.
    /**
     * @notice Executes a transaction from outside the account
     * @notice Basically enyone who has been given a signed transaction can execute it
     * @param _transaction The transaction to execute
     */
    function executeTransactionFromOutside(Transaction memory _transaction) external payable {
        bytes4 magic = _validateTransaction(_transaction);
        if (magic != ACCOUNT_VALIDATION_SUCCESS_MAGIC) {
            revert ZkMinimalAccount__InvalidSignature();
        }
        _executeTransaction(_transaction);
    }

    /**
     * @notice Defines who pays for the transaction
     * param _txHash The hash of the transaction to be used in the explorer
     * param _suggestedSignedHash The hash of the transaction that is signed by an EOA
     * @param _transaction The transaction itself
     */
    function payForTransaction(bytes32, /*_txHash*/ bytes32, /*_suggestedSignedHash*/ Transaction memory _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction memory _transaction)
        external
        payable
    {}
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateTransaction(Transaction memory _transaction) internal returns (bytes4 magic) {
        // call nonceholder
        // increment nonce
        //return IAccount.validateTransaction.selector;
        SystemContractsCaller.systemCallWithPropagatedRevert(
            Utils.safeCastToU32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );
        // check for fee to pay
        uint256 totalRequiredBalance = _transaction.totalRequiredBalance();
        if (totalRequiredBalance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }
        // check the signature
        bytes32 txHash = _transaction.encodeHash();
        address signer = ECDSA.recover(txHash, _transaction.signature);
        // DO I NEED MessageHashUtils.toEthSignedMessageHash(txHash) if encodeHash() already provides correct form ?

        bool isValidSigner = signer == owner();

        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC; //function selector
        } else {
            magic = bytes4(0); //function selector of 0
        }
        //(_transaction.signature, txHash) =
        // return the magic numbers
        return magic;
    }

    function _executeTransaction(Transaction memory _transaction) internal {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }

            if (!success) {
                revert ZkMinimalAccount__ExecutionFailed();
            }
        }
    }
}
