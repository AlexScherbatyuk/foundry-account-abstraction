// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkMinimalAccount.sol";
import {CodeConstances} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {ACCOUNT_VALIDATION_SUCCESS_MAGIC} from
    "@cyfrin/foundry-era-contracts/system-contracts/contracts/interfaces/IAccount.sol";
import {BOOTLOADER_FORMAL_ADDRESS} from "@cyfrin/foundry-era-contracts/system-contracts/contracts/Constants.sol";

contract ZkMinimalAccountTest is Test, CodeConstances {
    ZkMinimalAccount minimalAccount;
    ERC20Mock usdc;

    uint256 constant AMOUNT = 1e18;
    bytes32 constant EPTY_BYTES32 = bytes32(0);

    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        minimalAccount.transferOwnership(DEFAULT_ANVIL_ACCOUNT);
        usdc = new ERC20Mock();
        vm.deal(address(minimalAccount), AMOUNT);
    }

    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);
        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EPTY_BYTES32, EPTY_BYTES32, transaction);
        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testZkValidateTransaction() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction =
            _createUnsignedTransaction(minimalAccount.owner(), 113, dest, value, functionData);
        // Act
        transaction = _signTransaction(transaction);
        vm.prank(BOOTLOADER_FORMAL_ADDRESS);
        bytes4 magic = minimalAccount.validateTransaction(EPTY_BYTES32, EPTY_BYTES32, transaction);
        // Assert
        assertEq(magic, ACCOUNT_VALIDATION_SUCCESS_MAGIC);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    function _signTransaction(Transaction memory _transaction) internal view returns (Transaction memory) {
        bytes32 digest = MemoryTransactionHelper.encodeHash(_transaction);
        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = vm.sign(DEFAULT_ANVIL_KEY, digest);
        Transaction memory signedTransaction = _transaction;
        signedTransaction.signature = abi.encodePacked(r, s, v); // order is important
        return signedTransaction;
    }

    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);
        return Transaction({
            txType: transactionType, // type 113 (0x71)
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 16777216,
            gasPerPubdataByteLimit: 16777216,
            maxFeePerGas: 16777216,
            maxPriorityFeePerGas: 16777216,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}
