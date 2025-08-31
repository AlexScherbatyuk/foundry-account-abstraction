include .env



install:; forge install eth-infinitism/account-abstraction@v0.7.0 && forge install openzeppelin/openzeppelin-contracts@v5.0.2 && forge install cyfrin/foundry-era-contracts@0.0.3 && forge install cyfrin/foundry-devops@0.3.0


deploy-arb:; forge script script/DeployMinimal.s.sol --rpc-url ${ARBITRUM_RPC_URL} --account devKey --broadcast --verify
send-arb:; forge script script/SendPackedUserOp.s.sol --rpc-url ${ARBITRUM_RPC_URL} --account devKey --broadcast



#forge test --mt testZkOwnerCanExecuteCommands  --via-ir --optimize --optimizer-runs 200 --zksync

#forge test --mt testZkValidateTransaction --zksync --system-mode=true --via-ir --optimize 