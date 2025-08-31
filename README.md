# Foundry Account Abstraction

A comprehensive implementation of Account Abstraction (AA) on both Ethereum and zkSync Era, built with Foundry. This project demonstrates how to create, deploy, and interact with smart contract accounts that can execute transactions without requiring users to manage private keys directly.

## 🚀 Features

- **Ethereum Account Abstraction**: Implementation using EIP-4337 (Account Abstraction) with PackedUserOperation
- **zkSync Era Account Abstraction**: Native zkSync AA implementation using type 113 transactions
- **Minimal Account Contracts**: Lightweight, gas-efficient smart contract accounts
- **Comprehensive Testing**: Full test coverage for both Ethereum and zkSync implementations
- **Deployment Scripts**: Automated deployment and interaction scripts
- **Foundry Integration**: Built with Foundry for development, testing, and deployment

## 📋 Project Structure

```
├── src/
│   ├── ethereum/          # Ethereum AA implementation
│   │   └── MinimalAccount.sol
│   └── zksync/           # zkSync Era AA implementation
│       └── ZkMinimalAccount.sol
├── script/               # Deployment and interaction scripts
│   ├── DeployMinimal.s.sol
│   ├── HelperConfig.s.sol
│   └── SendPackedUserOp.s.sol
├── test/                 # Test files
│   ├── ethereum/        # Ethereum AA tests
│   └── zksync/          # zkSync AA tests
├── lib/                  # Dependencies
└── foundry.toml         # Foundry configuration
```

## 🏗️ Architecture

### Ethereum Account Abstraction (EIP-4337)

The `MinimalAccount` contract implements the standard EIP-4337 Account Abstraction pattern:

- **EntryPoint Integration**: Works with the standard EntryPoint contract
- **UserOperation Validation**: Validates signed user operations
- **Gas Management**: Handles gas limits and fees
- **Signature Verification**: ECDSA signature validation for transaction authorization

### zkSync Era Account Abstraction

The `ZkMinimalAccount` contract implements zkSync's native AA system:

- **Type 113 Transactions**: Uses zkSync's custom transaction type
- **Bootloader Integration**: Works with zkSync's bootloader system
- **Nonce Management**: Handles transaction nonces through system contracts
- **Gas Optimization**: Leverages zkSync's gas-efficient execution model

## 🛠️ Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- Node.js 18+ (for some dependencies)
- Access to Ethereum and zkSync RPC endpoints

## ⚡ Quick Start

### 1. Install Dependencies

```bash
# Install Foundry dependencies
make install

# Or manually:
forge install eth-infinitism/account-abstraction@v0.7.0
forge install openzeppelin/openzeppelin-contracts@v5.0.2
forge install cyfrin/foundry-era-contracts@0.0.3
forge install cyfrin/foundry-devops@0.3.0
```

### 2. Environment Setup

Create a `.env` file with your configuration:

```bash
# Network RPC URLs
ARBITRUM_RPC_URL=your_arbitrum_rpc_url
ZKSYNC_RPC_URL=your_zksync_rpc_url

# Private keys (for deployment and testing)
devKey=your_private_key
```

### 3. Build the Project

```bash
forge build
```

### 4. Run Tests

```bash
# Run all tests
forge test

# Run Ethereum-specific tests
forge test --match-contract MinimalAccountTest

# Run zkSync-specific tests
forge test --match-contract ZkMinimalAccountTest --zksync --system-mode=true
```

## 🚀 Deployment

### Deploy to Arbitrum

```bash
# Deploy the MinimalAccount contract
make deploy-arb

# Send a user operation
make send-arb
```

### Manual Deployment

```bash
# Deploy MinimalAccount
forge script script/DeployMinimal.s.sol --rpc-url $ARBITRUM_RPC_URL --account devKey --broadcast --verify

# Send UserOperation
forge script script/SendPackedUserOp.s.sol --rpc-url $ARBITRUM_RPC_URL --account devKey --broadcast
```

## 📚 Usage Examples

### Creating a User Operation

```solidity
// Generate a user operation for USDC approval
bytes memory functionData = abi.encodeWithSelector(
    IERC20.approve.selector, 
    approver, 
    amount
);

bytes memory executeCalldata = abi.encodeWithSelector(
    MinimalAccount.execute.selector, 
    usdcAddress, 
    0, 
    functionData
);

PackedUserOperation memory userOp = generateSignedUserOperation(
    executeCalldata, 
    config, 
    minimalAccountAddress
);
```

### Executing Transactions

```solidity
// Execute a transaction through the account
minimalAccount.execute(
    destination,    // Target contract
    value,         // ETH value to send
    functionData   // Function call data
);
```

## 🧪 Testing

The project includes comprehensive tests covering:

- **Account Creation**: Contract deployment and initialization
- **Transaction Execution**: Direct and user operation-based execution
- **Access Control**: Owner and EntryPoint authorization
- **Signature Validation**: ECDSA signature verification
- **Gas Management**: Gas limit and fee handling
- **Error Handling**: Proper revert conditions

### Running Specific Tests

```bash
# Test account execution
forge test --match-test testOwnerCanExecutesCommands

# Test signature recovery
forge test --match-test testRecoverSignedOp

# Test zkSync validation
forge test --match-test testZkValidateTransaction --zksync --system-mode=true
```

## 🔧 Configuration

### Foundry Configuration

The `foundry.toml` includes:

- **Remappings**: Library imports and dependencies
- **System Mode**: Required for zkSync testing
- **IR Mode**: Optimized compilation
- **Formatting**: Code style configuration

### Network Configuration

`HelperConfig.s.sol` manages network-specific settings:

- RPC endpoints
- Contract addresses (EntryPoint, USDC, etc.)
- Gas parameters
- Account configurations

## 📖 Key Concepts

### Account Abstraction

Account Abstraction allows users to:
- Use smart contracts as their primary accounts
- Execute transactions without managing private keys
- Implement custom transaction validation logic
- Use paymasters for gas fee management

### User Operations

User operations are the core of EIP-4337:
- **Sender**: The account address
- **Nonce**: Transaction ordering
- **CallData**: The actual transaction data
- **Signature**: Authorization proof
- **Gas Parameters**: Fee and limit management

### zkSync Integration

zkSync Era provides:
- **Native AA Support**: Built-in account abstraction
- **Gas Efficiency**: Optimized execution model
- **System Contracts**: Pre-deployed infrastructure
- **Type 113 Transactions**: Custom transaction format

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- [eth-infinitism](https://github.com/eth-infinitism/account-abstraction) for EIP-4337 implementation
- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [zkSync Era](https://era.zksync.io/) for zkSync integration
- [Foundry](https://getfoundry.sh/) for the development framework

## 📞 Support

For questions and support:
- Open an issue on GitHub
- Check the test files for usage examples
- Review the contract documentation

---

**Note**: This is a learning project. Do not use in production without thorough auditing and testing.


MinimalAccount: 0x5B17b78e34954A760D293655bAF440C817080C3E
AA transaction: 0x4cfa87c0ff80203bb5d06f847703ddf114af944383feedbfc2b59ad0dd9314e0