# Starknet messaging local development

This repository aims at giving the detailed steps to locally work
on Starknet messaging with `Anvil` and `Katana`.

## Requirements

Please before start, install:

-   [scarb](https://docs.swmansion.com/scarb/) to build cairo contracts.
-   [starkli](https://github.com/xJonathanLEI/starkli) to interact with Katana.
-   [katana](https://www.dojoengine.org/en/) to install Katana, that belongs to dojo.
-   [foundry](https://book.getfoundry.sh/getting-started/installation) to interact with Anvil.

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

3. Keep this terminal open for later use to send transactions on Anvil.


## Setup Starknet contracts

To setup Starknet contract, please follow those steps:

1. Update katana to have the latest features by running:
   ```bash
   dojoup -v nightly
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

   starkli declare target/dev/messaging_tuto_contract_msg.sierra.json --keystore-password ""

   starkli deploy 0x048ffd12e3e126938f0695eef1357eb7c45677e65d947cf4891b9598637703ca \
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
You can try to change the payload into the scripts to see how the contract on starknet behaves receiveing the message. Try to set both values to 0 for the struct. In the case of the value, you'll see a warning in Katana saying `Invalid value` because the contract is expected `123`.

### To send messages L2 -> L1:
```bash
# In the terminal that is inside the cairo folder you've used to run starkli commands to declare (ensure you've sourced the katana.env file).

starkli invoke 0x03e4b41d5bf9ece15bd6e194c734b87bf338b262cbe411d5b2d2facab245e9e9 \
    send_message_value 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1 \
    --keystore-password ""

starkli invoke 0x03e4b41d5bf9ece15bd6e194c734b87bf338b262cbe411d5b2d2facab245e9e9 \
    send_message_struct 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 1 2 \
    --keystore-password ""
```

You will then see Katana sending transactions to L1 to register the hashes of the messages,
simulating the work done by the `StarknetMessaging` contract on L1 on testnet or mainnet.

You've to wait few seconds to see the confirmation of Katana that the messages has been sent to Anvil:

```bash
2023-10-03T04:56:14.037491Z DEBUG katana_core::service::messaging::ethereum: Sending transaction on L1 to register messages...
2023-10-03T04:56:21.048573Z  INFO messaging: Message sent to settlement layer:
|     hash     | 0xd7da83e6fc13a8cdbe7d43e844bc3fa318bb12f88ea81c00dae33830723d1c88
| from_address | 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973
|  to_address  | 0xe7f1725e7734ce288f8367e1bb143e90bb3f0512
|   payload    | [0x1]


2023-10-03T04:56:22.037049Z DEBUG katana_core::service::messaging::ethereum: Sending transaction on L1 to register messages...
2023-10-03T04:56:29.046380Z  INFO messaging: Message sent to settlement layer:
|     hash     | 0xfc16ed92ba1eb422d709dd38b684e2addc1dcd628fbd9b9acb31c57ad648ef35
| from_address | 0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973
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
