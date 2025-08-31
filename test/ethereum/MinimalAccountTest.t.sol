// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig, CodeConstances} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp, PackedUserOperation, IEntryPoint} from "script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract MinimalAccountTest is CodeConstances, Test {
    using MessageHashUtils for bytes32;

    MinimalAccount minimalAccount;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;
    ERC20Mock usdc;
    SendPackedUserOp sendPackedUserOp;

    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        config = helperConfig.getConfig();
        sendPackedUserOp = new SendPackedUserOp();
        usdc = new ERC20Mock();
    }

    // USDC Approval
    // msg.sender -> MinimalAccount
    // approve some amount
    // USDC contract
    // come from the netrypoint

    // 1. We want to test that account owner can call MinimalAccount and MinimalAccount successefully calls USDC contract
    function testOwnerCanExecutesCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        // Act
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public view {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOp);
        // Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);
        // Assert
        console2.log("Actual Signer: ", actualSigner);
        console2.log("Singer: ", config.account);
        console2.log("MinimalAccount owner: ", minimalAccount.owner());
        console2.log("MinimalAccount address: ", address(minimalAccount));
        console2.log("Anvil default address: ", DEFAULT_ANVIL_KEY);
        console2.log("EntryPoint address: ", config.entryPoint);
        console2.log("msg.sender: ", msg.sender);
        assertEq(actualSigner, minimalAccount.owner());
    }

    // 1. Sign user op
    // 2. Call validate use op
    // 3. Assert the return is correct
    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(config.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, address(minimalAccount));
        // bytes32 userOperationHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(minimalAccount), 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        vm.prank(randomUser);
        IEntryPoint(config.entryPoint).handleOps(ops, payable(randomUser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
