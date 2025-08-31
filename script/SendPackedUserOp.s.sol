// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {HelperConfig, CodeConstances} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DevOpsTools} from "@cyfrin/foundry-devops/DevOpsTools.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SendPackedUserOp is CodeConstances, Script {
    using MessageHashUtils for bytes32;

    // Make sure you trust this user - don't run this on Mainnet!
    address constant RANDOM_APPROVER = 0x7e7cCf58d0670390B039d94cE2c3Cd54BeAE09Be;

    function run() public {
        // Setup
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address dest = config.usdc; // arbitrum mainnet USDC address
        uint256 value = 0;
        address minimalAccountAddress = DevOpsTools.get_most_recent_deployment("MinimalAccount", block.chainid);

        bytes memory functionData = abi.encodeWithSelector(IERC20.approve.selector, RANDOM_APPROVER, 1e18);
        bytes memory executeCalldata =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory userOp = generateSignedUserOperation(executeCalldata, config, minimalAccountAddress);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        // Send transaction
        vm.startBroadcast();
        IEntryPoint(config.entryPoint).handleOps(ops, payable(config.account));
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // 1. Generate unsigned data
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsainedUserOperation(callData, minimalAccount, nonce);
        // 2. Ge userOp hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        // 3. Sign it, and return it
        // if using --account during scrip run FOundry will use unlocked account private key instead of just an address
        uint8 v;
        bytes32 r;
        bytes32 s;
        if (block.chainid == LOCAL_CHAIN_ID) {
            (v, r, s) = vm.sign(DEFAULT_ANVIL_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        userOp.signature = abi.encodePacked(r, s, v); // !important order is r, s, v
        return userOp;
    }

    function _generateUnsainedUserOperation(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
