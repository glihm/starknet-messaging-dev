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

1. Update katana on the 0.4.4 version to match starkli compatible version (temporary fix due to RPC incompatibility):

   ```bash
   starkliup -v 0.2.9
   dojoup -v 0.6.0
   ```

2. Then open a terminal and starts katana by passing the messaging configuration where Anvil contract address and account keys are setup:

   ```bash
   katana --messaging anvil.messaging.json
   ```

   Katana will now poll anvil logs exactly as the Starknet sequencer does on the `StarknetMessaging` contract on ethereum.

3. In a new terminal, go into cairo folder and use starkli to declare and deploy the contracts:

   ```bash
   cd cairo

   # To ensure starkli env variables are setup correctly.
   source katana.env

   scarb build

   starkli declare ./target/dev/messaging_tuto_contract_msg.contract_class.json --keystore-password ""

   starkli deploy 0x051a7b3565ab605475512178fc157d743c9a394242ab60207a6932a25e087456 \
       --salt 0x1234 \
       --keystore-password ""
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
2024-01-26T12:42:17.934100Z  INFO messaging: L1Handler transaction added to the pool:
|      tx_hash     | 0x6d7a44291f7633fb379ce0e1eff254b6c6d60a2047d4542c627f6f883b43d2d
| contract_address | 0x02defe8eeb8e8c1cf59de8ba1a6844e8781d27e2ee20439204757b338f8ae74c
|     selector     | 0x5421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc
|     calldata     | [0xe7f1725e7734ce288f8367e1bb143e90bb3f0512, 0x7b]

2024-01-26T12:42:17.934808Z TRACE executor: Event emitted keys=[0x7acfbcb48c15c0b483370386499142617673e79567c0ef3937c3b2d57ac505, 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512]
```

You can try to change the payload into the scripts to see how the contract on starknet behaves receiveing the message. Try to set both values to 0 for the struct. In the case of the value, you'll see a warning in Katana saying `Invalid value` because the contract is expected `123`.

### To send messages L2 -> L1:

```bash
# In the terminal that is inside the cairo folder you've used to run starkli commands to declare (ensure you've sourced the katana.env file).

starkli invoke 0x02defe8eeb8e8c1cf59de8ba1a6844e8781d27e2ee20439204757b338f8ae74c \
    send_message_value 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1 \
    --keystore-password ""

starkli invoke 0x02defe8eeb8e8c1cf59de8ba1a6844e8781d27e2ee20439204757b338f8ae74c \
    send_message_struct 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1 2 \
    --keystore-password ""
```

You will then see Katana sending transactions to L1 to register the hashes of the messages,
simulating the work done by the `StarknetMessaging` contract on L1 on testnet or mainnet.

You've to wait few seconds to see the confirmation of Katana that the messages has been sent to Anvil:

```bash
2024-01-26T12:45:25.932340Z DEBUG katana_core::service::messaging::ethereum: Sending transaction on L1 to register messages...
2024-01-26T12:45:32.938959Z  INFO messaging: Message sent to settlement layer:
|     hash     | 0xadd65fa392fcdab9e8fdfd1ea4a1c78798bdf9c826af6449e2454829c6e80359
| from_address | 0x2defe8eeb8e8c1cf59de8ba1a6844e8781d27e2ee20439204757b338f8ae74c
|  to_address  | 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512
|   payload    | [0x1]


2024-01-26T12:46:11.932363Z DEBUG katana_core::service::messaging::ethereum: Sending transaction on L1 to register messages...
2024-01-26T12:46:18.936855Z  INFO messaging: Message sent to settlement layer:
|     hash     | 0x10a085a7228104f7c9558bf7409da239cff0624b9df4301ccb2cb042cd1a3ede
| from_address | 0x2defe8eeb8e8c1cf59de8ba1a6844e8781d27e2ee20439204757b338f8ae74c
|  to_address  | 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512
|   payload    | [0x1, 0x2]
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
