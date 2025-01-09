# Starknet messaging local development

This repository aims at giving the detailed steps to locally work
on Starknet messaging with `Anvil` and `Katana`.

## Requirements

Please before start, install:

- [scarb](https://docs.swmansion.com/scarb/) to build cairo contracts.
- [starkli](https://github.com/xJonathanLEI/starkli) to interact with Katana.
- [katana](https://www.dojoengine.org/en/) to install Katana, that belongs to dojo.
- [foundry](https://book.getfoundry.sh/getting-started/installation) to interact with Anvil.

If it's your first time cloning the repository, please install forge dependencies as follow:

```bash
cd solidity
forge install
```

## Setup Ethereum contracts

To setup Ethereum part for local testing, please follow those steps:

1. Start Anvil in a new terminal with the command `anvil`.

2. In an other terminal, change directory into the solidity folder:

   ```bash
   cd solidity

   # Copies the example of anvil configuration file into .env that is loaded by
   # foundry automatically.
   cp anvil.env .env

   # Ensure all variables are exported for the use of forge commands.
   source .env
   ```

3. Then, we will deploy the `StarknetMessagingLocal` contract that simulates the work
   done by the `StarknetMessaging` core contract on Ethereum. Then we will deploy the `ContractMsg.sol`
   to send/receive message. To do so, run the following:

   ```bash
   forge script script/LocalTesting.s.sol:LocalSetup --broadcast --rpc-url ${ETH_RPC_URL}
   ```

4. Keep this terminal open for later use to send transactions on Anvil.

## Setup Starknet contracts

To setup Starknet contract, please follow those steps:

1. Update katana on the 1.0.9 version to use the latest RPC version:

   ```bash
   starkliup
   dojoup -v 1.0.9
   ```

2. Then open a terminal and starts katana by passing the messaging configuration where Anvil contract address and account keys are setup:

   ```bash
   katana --dev --messaging anvil.messaging.json
   ```

   Katana will now poll anvil logs exactly as the Starknet sequencer does on the `StarknetMessaging` contract on ethereum.

3. In a new terminal, go into cairo folder and use starkli to declare and deploy the contracts:

   ```bash
   cd cairo

   # Scarb version is defined by `.tool-versions`
   # Or use `asdf install scarb 2.8.4` then `asdf local scarb 2.8.4`.

   scarb build

   starkli declare --account katana-0 \
      --compiler-version 2.8.5 \
      ./target/dev/messaging_tuto_contract_msg.contract_class.json

   starkli deploy --account katana-0 \
      --salt 0x1234 \
      0x0727468c660613faf8ebfbf149f05a9c3016702c362fccb69e9addb6ed1b934c
   ```

4. Keep this terminal open to later send transactions on Katana.

## Interaction between the two chains

Once you have both dev nodes setup with contracts deployed, we can start interacting with them.
You can use `starkli` and `cast` to send transactions. But for the sake of simplicity, some scripts
are already written to replace `cast` usage.

### To send messages L1 -> L2:

```bash
# In the terminal that is inside solidity folder you've used to run forge script previously (ensure you've sourced the .env file).
forge script script/SendMessage.s.sol:Value --broadcast --rpc-url ${ETH_RPC_URL}
forge script script/SendMessage.s.sol:Struct --broadcast --rpc-url ${ETH_RPC_URL}
```

You will then see Katana picking up the messages, and executing exactly as Starknet would
do with Ethereum on testnet or mainnet.

Example here where you can see the details of the message and the event being emitted `ValueReceivedFromL1`.

```bash
2025-01-08T21:47:12.431364Z  INFO messaging: L1Handler transaction added to the pool. tx_hash=0x51ab77a5b4fb2188fd270c59f56916bfff4636ca4da8a0a95438e4c2287437c contract_address=0x26558b1ab48a5411f589d8ec66fdef5e6dd9c2f88f7f9274b88997444248aec selector=0x5421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc calldata=0xe7f1725e7734ce288f8367e1bb143e90bb3f0512, 0x7b
2025-01-08T21:47:12.431377Z  INFO pool: Transaction received. hash="0x51ab77a5b4fb2188fd270c59f56916bfff4636ca4da8a0a95438e4c2287437c"
2025-01-08T21:47:12.431398Z  INFO messaging: Collected messages from settlement chain. msg_count=1
2025-01-08T21:47:12.432088Z TRACE executor: Transaction resource usage. usage="steps: 1385 | memory holes: 0 | pedersen_builtin: 12 | range_check_builtin: 19"
```

You can try to change the payload into the scripts to see how the contract on starknet behaves receiveing the message. Try to set both values to 0 for the struct. In the case of the value, you'll see a warning in Katana saying `Invalid value` because the contract is expected `123`.

### To send messages L2 -> L1:

```bash
# In the terminal that is inside the cairo folder you've used to run starkli commands to declare (ensure you've sourced the katana.env file).

starkli invoke 0x26558b1ab48a5411f589d8ec66fdef5e6dd9c2f88f7f9274b88997444248aec \
    send_message_value 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1

starkli invoke 0x26558b1ab48a5411f589d8ec66fdef5e6dd9c2f88f7f9274b88997444248aec \
    send_message_struct 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1 2
```

You will then see Katana sending transactions to L1 to register the hashes of the messages,
simulating the work done by the `StarknetMessaging` contract on L1 on testnet or mainnet.

You've to wait few seconds to see the confirmation of Katana that the messages has been sent to Anvil:

```bash
2025-01-08T21:48:17.978664Z  INFO pool: Transaction received. hash="0x6aba5937d0ed0ce06486cc554898306cc7670cc85e82d6f39ee1c67bd0ab885"
2025-01-08T21:48:17.990643Z TRACE executor: Transaction resource usage. usage="steps: 5913 | memory holes: 53 | ec_op_builtin: 3 | pedersen_builtin: 20 | range_check_builtin: 136"
2025-01-08T21:48:17.991560Z  INFO katana::core::backend: Block mined. block_number=5 tx_count=1
2025-01-08T21:48:18.449588Z  INFO messaging: Collected messages from settlement chain. msg_count=0
2025-01-08T21:48:18.450702Z  INFO messaging: Message sent to settlement layer. hash=0x37857b83ff01d1f42340b94d28c148939c6a050e6c2f25bfc425cf2d760b6553 from_address=0x26558b1ab48a5411f589d8ec66fdef5e6dd9c2f88f7f9274b88997444248aec to_address=0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 payload=0x1
2025-01-08T21:48:18.450738Z  INFO messaging: Sent messages to the settlement chain. msg_count=1


2025-01-08T21:48:43.952621Z  INFO pool: Transaction received. hash="0x6753e9c03461a3adeb944294bfb76d256934aeb9fc693082aab8c584445dc9a"
2025-01-08T21:48:43.964609Z TRACE executor: Transaction resource usage. usage="steps: 5937 | memory holes: 53 | ec_op_builtin: 3 | pedersen_builtin: 21 | range_check_builtin: 136"
2025-01-08T21:48:43.965437Z  INFO katana::core::backend: Block mined. block_number=6 tx_count=1
2025-01-08T21:48:44.467839Z  INFO messaging: Collected messages from settlement chain. msg_count=0
2025-01-08T21:48:44.471201Z  INFO messaging: Message sent to settlement layer. hash=0x9a853bfe92bb85e2d377cba8df36ef8af1a1da1c8f8a9c2c966ad737e8f79e8b from_address=0x26558b1ab48a5411f589d8ec66fdef5e6dd9c2f88f7f9274b88997444248aec to_address=0xe7f1725e7734ce288f8367e1bb143e90bb3f0512 payload=0x1, 0x2
2025-01-08T21:48:44.471214Z  INFO messaging: Sent messages to the settlement chain. msg_count=1
```

To then consume the messages, you must send a transaction on Anvil, exactly as you would do
on L1 for testnet or mainnet.

```bash
# In the terminal used for solidity / forge stuff.

# Try to run a first time, it should pass. Try to run a second time, you should have the
# error INVALID_MESSAGE_TO_CONSUME because the message is already consumed.
# Or try to change the payload value or address in the script, to see how the consumption
# of the message is denied.
forge script script/ConsumeMessage.s.sol:Value --broadcast -vvvv --rpc-url ${ETH_RPC_URL}

# Same here, try to consume a message sent with a struct inside.
forge script script/ConsumeMessage.s.sol:Struct --broadcast -vvvv --rpc-url ${ETH_RPC_URL}
```

And that's it!

With those examples, you can now try your own messaging contracts, mostly to ensure that your serialization/deserialization
of arguments between solidity and cairo is done correctly.

# L2-L3 messaging

When messaging is between L2 (starknet) and L3 (appchain), the general flow is the same. A core contract is deployed on L2, and the L3 sequencer is configured to send messages / receive messages from the L2 core contract.

The core contract is piltover, and can be found [here](https://github.com/keep-starknet-strange/piltover), and more specifically the [messaging interface](https://github.com/keep-starknet-strange/piltover/blob/main/src/messaging/interface.cairo).

In the context of testing here, we are only interested in the messaging interface of the core contract. In the same fashion we skip the proof generation and verification steps for L1-L2 messaging, we will skip the proof generation and verification steps for L2-L3 messaging by registrering the messages directly calling the core contract test functions on L2.

## Startup the two sequencers (L2 and L3)

```bash
# Starknet sequencer (L2) acting as Starknet.
katana --dev --http.port 9999
```

The appchain Katana must be started with the `--messaging` flag, pointing to the L2 sequencer
and the core contract address.

Currently, to support starknet messaging, you must clone dojo and build katana with the `starknet-messaging` feature enabled.
A future release will include the starknet messaging feature by default.
```bash
git clone https://github.com/dojoengine/dojo.git
cd dojo
git checkout refactor/sn-messaging
cargo build --bin katana -r --features starknet-messaging
```

Start the appchain sequencer pointing to the L2 sequencer (the configuration file already contains the L2 core contract address).
```bash
# Appchain sequencer (L3).
/dojo/target/release/katana --dev --messaging l3.messaging.json --http.port 7777
```

Now open a new terminal and heads to `cairo` folder from where the next commands will be executed.
```bash
cd cairo
scarb build

# Setup env with sequencer URLs.
export KATANA_L2_RPC=http://0.0.0.0:9999
export KATANA_L3_RPC=http://0.0.0.0:7777
```

## Setup the L3 (Appchain)

Declare and deploy the cairo contract on the appchain:
```bash
starkli declare target/dev/messaging_tuto_contract_msg_starknet.contract_class.json \
   --rpc ${KATANA_L3_RPC} \
   --account katana-0 \
   --compiler-version 2.8.5

starkli deploy 0x07829332f84c7af581879a18fa29d9d3018da0ddb5972537d19a6b14b159fab4 \
   --rpc ${KATANA_L3_RPC} \
   --account katana-0 \
   --salt 0x1234
```

The cairo contract should be deployed now at address: `0x07587acd21bd6c5465bc5e8e3bc9de0b378b02853aa3a79a539f977fa34f81c1`.
```bash
export CONTRACT_MSG_ADDRESS=0x07587acd21bd6c5465bc5e8e3bc9de0b378b02853aa3a79a539f977fa34f81c1
```

## Setup of the L2 (Starknet)

Pull and compile piltover with the messaging test feature (use a new terminal):
```bash
# Clone.
git clone https://github.com/keep-starknet-strange/piltover.git
cd piltover
git checkout feat/messaging-test

# Build with the messaging test feature enabled.
scarb build --features messaging_test
```

Declare and deploy the piltover core contract:
```bash
# Declare the piltover core contract.
starkli declare target/dev/piltover_appchain.contract_class.json \
   --rpc http://0.0.0.0:9999 \
   --account katana-0 \
   --compiler-version 2.8.5

# Deploy the piltover core contract with the 4 constructor arguments.
# owner: ContractAddress,
# state_root: felt252,
# block_number: felt252,
# block_hash: felt252,
#
# For messaging test purposes, those values are not important.
# If you use a modified version of the piltover core contract, you may adjust the class hash.
starkli deploy 0x0034c8b964ac018ee916398fdb59b5d1ad5946f23309bdac7b22db25b6c3e879 \
   --rpc http://0.0.0.0:9999 \
   --account katana-0 \
   --salt 0x1234 \
   0 0 0 0
```

The piltover contract should be deployed now at address: `0x03df9031d9c01ea8f3104593d8340ae12e755af0aa6a0a2cbcf5620cb78614bf`.
```bash
export PILTOVER_ADDRESS=0x03df9031d9c01ea8f3104593d8340ae12e755af0aa6a0a2cbcf5620cb78614bf
```

Let's now deploy an other contract on Starknet to send messages to an L3 contract:
```bash
# Use the terminal already opened in the cairo folder and sequencer URLs already setup.
cd cairo
```

To initialize the contract, the piltover address must be sent to the constructor of the contract. This way,
the contract will be able to send/receive messages using the piltover core contract.
```bash
starkli declare target/dev/messaging_tuto_sn_1.contract_class.json \
   --rpc ${KATANA_L2_RPC} \
   --account katana-0 \
   --compiler-version 2.8.5

# Constructor accepts two arguments:
# - The piltover address.
# - The appchain contract address.
starkli deploy 0x00ba5efd4a5d05f817667c5227f566750465ac19146b1cb41979eced49d054e7 \
   --rpc ${KATANA_L2_RPC} \
   --account katana-0 \
   --salt 0x1234 \
   ${PILTOVER_ADDRESS} ${CONTRACT_MSG_ADDRESS}
```

The `sn_1` contract should be deployed now at address: `0x0575462075b91eccde9925a1efd50039d73ce1b19c366e406b5018f46e436f43`.
```bash
export SN_1_ADDRESS=0x0575462075b91eccde9925a1efd50039d73ce1b19c366e406b5018f46e436f43
```

## Interaction between the two chains

### To send messages L2 -> L3:

Let's use the `sn_1` contract to send a message to the `contract_msg_starknet` contract.
Since the `send_message` of `sn_1` contract is generic, we must specify the `l1_handler` selector to use.
In this case, the entrypoint is `msg_handler_value`.
```bash
starkli selector msg_handler_value
# 0x005421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc
```
```bash
starkli invoke ${SN_1_ADDRESS} \
   --rpc ${KATANA_L2_RPC} \
   --account katana-0 \
   send_message ${CONTRACT_MSG_ADDRESS} 0x005421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc 888
```
A valid message sent should look like this in the Katana logs:
```bash
2025-01-09T04:32:22.327874Z  INFO messaging: L1Handler transaction added to the pool. tx_hash=0x7c5600948c77c6cb7ab383260ee26b09e07d9ad770faa5281356e92e95cbfe5 contract_address=0x236231e9d5206ef2c5b884a37d966f5986cb83ea7805d4c9e29c61083008bf3 selector=0x5421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc calldata=0x5b2c13c75ad55b538c53aec3ce84e29ff20f4b86cdc502737e85aa303982ab6, 0x378
2025-01-09T04:32:22.327917Z  INFO pool: Transaction received. hash="0x7c5600948c77c6cb7ab383260ee26b09e07d9ad770faa5281356e92e95cbfe5"
2025-01-09T04:32:22.327971Z  INFO messaging: Collected messages from settlement chain. msg_count=1
2025-01-09T04:32:22.329128Z TRACE executor: Transaction resource usage. usage="steps: 1287 | memory holes: 0 | reverted steps: 0 | pedersen_builtin: 12 | range_check_builtin: 18"
2025-01-09T04:32:22.330332Z  INFO katana::core::backend: Block mined. block_number=6 tx_count=1
```

You can try to change the value, and you will see Katana printing the execution error:
```bash
2025-01-09T04:30:46.334599Z  INFO messaging: L1Handler transaction added to the pool. tx_hash=0x5ae9630ef6fca216ae7d3637b969988a0a61e085932fce071bc4a726d4f7cce contract_address=0x236231e9d5206ef2c5b884a37d966f5986cb83ea7805d4c9e29c61083008bf3 selector=0x5421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc calldata=0x5b2c13c75ad55b538c53aec3ce84e29ff20f4b86cdc502737e85aa303982ab6, 0x372
2025-01-09T04:30:46.334648Z  INFO pool: Transaction received. hash="0x5ae9630ef6fca216ae7d3637b969988a0a61e085932fce071bc4a726d4f7cce"
2025-01-09T04:30:46.334713Z  INFO messaging: Collected messages from settlement chain. msg_count=1
2025-01-09T04:30:46.335763Z  INFO katana::executor::blockifier: Executing transaction. hash="0x5ae9630ef6fca216ae7d3637b969988a0a61e085932fce071bc4a726d4f7cce" error=Entry point execution error: 0x496e76616c69642076616c7565 ('Invalid value')
2025-01-09T04:30:46.336622Z  INFO katana::core::backend: Block mined. block_number=4 tx_count=0
```

### To send messages L3 -> L2:

To send message from L3 to L2, the transaction must be sent to the `contract_msg_starknet` contract,
and the L3 sequencer (in test mode) at the end of each block will send all the message hashes that
have been registered in the transactions of the block to register them on the L2 as ready to be consumed.

```bash
starkli invoke ${CONTRACT_MSG_ADDRESS} \
   --rpc ${KATANA_L3_RPC} \
   --account katana-0 \
   send_message ${SN_1_ADDRESS} 123
```

Let's consume the message on Starknet since it has been registered:
```bash
starkli invoke ${SN_1_ADDRESS} \
   --rpc ${KATANA_L2_RPC} \
   --account katana-0 \
   consume_message_value 123
```
