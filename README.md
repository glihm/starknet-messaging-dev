# Starknet L3 appchain messaging local development with Saya and Katana

This repository aims at giving the detailed steps to locally work
on Starknet messaging with `Katana` and `Saya` in the context of L3 appchain on the top of Starknet.

## Requirements

Please before start, install:

- [scarb](https://docs.swmansion.com/scarb/) to build cairo contracts.
   ```bash
   asdf plugin add scarb https://github.com/software-mansion/asdf-scarb.git
   asdf install scarb 2.13.1
   ```
- [sozo](https://github.com/dojoengine/sozo) installed via ASDF is the easiest way to go and you must use the latest version `1.8.5` to have access to declare/deploy/invoke commands.
   ```bash
   asdf plugin add sozo https://github.com/dojoengine/asdf-sozo.git
   asdf install sozo 1.8.5
   ```
- [saya](https://github.com/dojoengine/saya) installed via ASDF:
   ```bash
   asdf plugin add saya https://github.com/dojoengine/asdf-saya.git
   asdf install saya 0.2.1
   ```
- [katana](https://github.com/dojoengine/katana) you must currently use this [very specific version 1.7.0-snos.3](https://github.com/dojoengine/katana/pkgs/container/katana/593195481?tag=v1.7.0-snos.3) via docker for the L3 sequencer. For the L2 sequencer, you can use the latest stable version of Katana.

To follow the tutorial, it is recommended to open 4 terminals:
1. One to spinup Katana L2 sequencer.
2. One to spinup Katana L3 sequencer.
3. One to start Saya.
4. One to send commands and export the environment variables for easy execution of the commands.

Also, Katana supports persistency. So if you have one of the L2 or L3 that is well already,
don't forget to spin it up with a db. Like so, you can restart it quickly with all the state from the database.

## Context

When messaging is between L2 (starknet) and L3 (appchain), the general flow is the following. A core contract is deployed on L2 (Starknet), and the L3 sequencer (Katana) is configured to send messages / receive messages from the L2 core contract (Piltover).

The core contract is piltover, and can be found [here](https://github.com/keep-starknet-strange/piltover), and more specifically the [messaging interface](https://github.com/keep-starknet-strange/piltover/blob/main/src/messaging/interface.cairo).

Katana is already including a piltover compiled contract that we will see in a minute. The exact revision used for piltover is on the [Cartridge fork of the piltover repository](https://github.com/cartridge-gg/piltover/tree/feat/remove-snos-output).

The canonical flow to have the appchain state and messages updates on Starknet is the following:

1. When going L2 -> L3, a contract on Starknet sends a message by calling the core contract (Piltover), which emits an event that the L3 sequencer will pick up and execute a `L1HandlerTransaction` almost immediately after the block containing this event has been mined. This doesn't require any proof to be generated. To be executed by such method, the contract on L3 must have an entrypoint marked as `#[l1_handler]`.
2. When going L3 -> L2, a contract on the appchain (L3) sends a message (using the `send_message_to_l1_syscall`). When the L3 sequencer will execute a transaction with this syscall, the message will be included in the block. Then, when the block execution is replayed and proven by the prover (done by Saya), the message will then be part of the proof output. Finally, when the proof will be submitted and verified on Starknet, this is where the message will be ready to be consumed via the core contract (Piltover) on L2.

In order to shorten the development cycle, Saya can be used to mock the proof generation and piltover will use a mocked fact registry. Doing so, the L2-L3 messaging flow can be tested locally in few seconds without having to wait for the proof generation (which is the longest part of the flow).

## Contracts

Few contracts involved here:

1. `fact_registry_mock`: Mock contract to be deployed on Starknet (L2) to mock the fact registry. Since we are not using actual proofs, we need to mock the fact registry to have a valid proof.
2. `sn_msg`: Contract to be deployed on Starknet (L2) to receive/send messages to the appchain (L3).
3. `appc_msg_sn`: Contract to be deployed on the appchain (L3) to receive/send messages to Starknet (L2).

As you notice, piltover is not listed here. This is because Katana includes an `init` command that does it for us. Since Piltover requires specific configuration to match the generated proofs, we let Katana handling this automatically.

Let's head to the `cairo` folder and compile the contracts:
```bash
# Open a terminal and keep this one for executing commands and exporting environment variables.
cd cairo

asdf install

scarb build
```

## Setup the L2 (Starknet)

Let's start by starting the sequencer acting like Starknet (L2). You can use the latest stable version of Katana for this one.

```bash
# In an other terminal.
katana --dev --dev.no-fee --http.port 50000
```
```bash
export KATANA_L2_RPC=http://localhost:50000
```

Let's then declare and deploy the mocked fact registry contract:
```bash
sozo declare target/dev/sn_msg_dev_fact_registry_mock.contract_class.json \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

sozo deploy 0x01d42b549cf7a09fc7ffdd176a0addf6e7d26d81678240597e58f1103952faf8 \
   --katana-account katana0 \
   --salt 0x1234 \
   --rpc-url ${KATANA_L2_RPC}

# Update to your address depending on your Katana version it may change.
export FACT_REGISTRY_MOCK_ADDRESS=0x03b041d3612bc1f29331e8de56945a1f0a580001e59a7c93e81d69e07981027b
```

Now, let's use Katana init to deploy and configure piltover for us. For this action, you must use the Katana version specific to the L3 appchain (v1.7.0-snos.2).

If you are using a different docker runtime, you may need to change the `KATANA_L2_RPC` environment variable to something like:
```bash
# Example using Colima.
export KATANA_L2_RPC_DOCKER=http://host.lima.internal:50000

# Otherwise, just use the local address.
export KATANA_L2_RPC_DOCKER=http://localhost:50000
```

We use an other variable here, since it's only for the dockerized version of Katana to correctly target the L2 sequencer.
Otherwise, from your terminal, when you will want to send transactions to the L2 sequencer, you will use `KATANA_L2_RPC` environment variable.

The next command is quite big, but the key points are:
1. Using a volume to ensure the chain configuration is persisted between runs.
2. Using `--env` to pass the variables exported in our current terminal session.
3. Using `--network=host` to ensure the container can reach the L2 sequencer without worrying about the network configuration.

```bash
# Create the named volume for the Katana L3 DB.
docker volume create katana-l3

# The account address and private key matches default katana accounts if you have used a recent
# version of Katana for the Starknet L2 we just started.
docker run --rm -it --name katana-l3 \
--env FACT_REGISTRY_MOCK_ADDRESS=${FACT_REGISTRY_MOCK_ADDRESS} \
--env KATANA_L2_RPC_DOCKER=${KATANA_L2_RPC_DOCKER} \
-v katana-l3:/data \
--network=host \
ghcr.io/dojoengine/katana:v1.7.0-snos.3 \
katana init \
--settlement-chain ${KATANA_L2_RPC_DOCKER} \
--id katana-l3 \
--settlement-account-private-key 0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912 \
--settlement-account-address 0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec \
--settlement-facts-registry ${FACT_REGISTRY_MOCK_ADDRESS} \
--output-path /data/katana-l3.json

# Take note of the piltover address and export it (katana uses an internal salt for this contract, it will change between runs. Use a volume for Katana DB if you want to maintain the contract).
export PILTOVER_ADDRESS=0x77e3020f9e6ce3d6e7cbbf8e35a302c1658d3c5897409a5f9e6ba2812b858fb
```

The Katana outputs the piltover address in the log this way:
```bash
✓ Deployment successful (0x77e3020f9e6ce3d6e7cbbf8e35a302c1658d3c5897409a5f9e6ba2812b858fb) at block #4
```

Now that we have the piltover address, we can deploy the `sn_msg` contract on Starknet:
```bash
sozo declare target/dev/sn_msg_dev_sn_msg.contract_class.json \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

sozo deploy 0x011dceea1eeb800a2a87454e424acb9158b5c649687d92a045c3eb6b73a182db \
   --constructor-calldata ${PILTOVER_ADDRESS} \
   --salt 0x1234 \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

# Take note of the address and export it, it will change between runs since Piltover address is
# changing too (and is passed to the constructor of the sn_msg contract).
export SN_MSG_ADDRESS=0x03c87be0be4d0ff385fe08d8beb0a1c2861c8133d54dfa73e27b082748b5c2a1
```

## Setup the L3 (Appchain)

If you've noticed, we've used a `--id` flag for Katana `init` command. This saves a file locally with the chain configuration, which includes the messaging configuration. We then use the `--chain` flag to use this file (note that this is a different concept than `--chain-id`).

```bash
docker run --rm -it --name katana-l3 \
-v katana-l3:/data \
--network=host \
ghcr.io/dojoengine/katana:v1.7.0-snos.3 \
katana --chain /data/katana-l3.json --http.port 51000

# For more logs, you can add this --env variable to the command:
--env RUST_LOG="katana=info,rpc=info,node=info,messaging=trace,executor=trace,pool=trace"

# And then export the RPC URL:
export KATANA_L3_RPC=http://localhost:51000
```

Please note that since we have a specific chain spec for this L3 appchain, the account generated may change depending on your configuration. When Katana is starting, the account will be displayed:
```bash

PREDEPLOYED CONTRACTS
==================

| Contract        | STRK Fee Token
| Address         | 0x2e7442625bab778683501c0eadbc1ea17b3535da040a12ac7d281066e915eea
| Class Hash      | 0xa2475bc66197c751d854ea8c39c6ad9781eb284103bcd856b58e6b500078ac

| Contract        | Universal Deployer
| Address         | 0x41a78e741e5af2fec34b695679bc6891742439f7afb8484ecd7766661ad02bf
| Class Hash      | 0x7b3e05f48f0c69e4a65ce5e076a66271a527aff2c34ce1083ec6e1526997a69

| Contract        | Account Contract
| Class Hash      | 0x7dc7899aa655b0aae51eadff6d801a58e97dd99cf4666ee59e704249e51adf2


PREFUNDED ACCOUNTS
==================

| Account address |  0x1f401c745d3dba9b9da11921d1fb006c96f571e9039a0ece3f3b0dc14f04c3d
| Private key     |  0x7230b49615d175307d580c33d6fda61fc7b9aec91df0f5c1a5ebe3b8cbfee02
| Public key      |  0x78e6e3e4a50285be0f6e8d0b8a61044033e24023df6eb95979ae4073f159ae6
```

```bash
# Export them to ease the following commands:
export APPC_ACCOUNT_ADDRESS=0x1f401c745d3dba9b9da11921d1fb006c96f571e9039a0ece3f3b0dc14f04c3d
export APPC_PRIVATE_KEY=0x7230b49615d175307d580c33d6fda61fc7b9aec91df0f5c1a5ebe3b8cbfee02
```

Due to an issue in Sozo that needs to be fixed, we will need some gas definitions
to make sure we can declare a class on Katana L3.

```bash
SOZO_GAS_DEFINITIONS=(--l1-data-gas 20000000000 --l1-gas 20000000000 --l1-gas-price 20000000000 --l2-gas-price 20000000000 --l1-data-gas-price 20000000000 --l2-gas 20000000000)
```

We can now declare and deploy the `appc_msg_sn` contract on the L3:
```bash
sozo declare target/dev/sn_msg_dev_appc_msg_sn.contract_class.json \
   "${SOZO_GAS_DEFINITIONS[@]}" \
   --account-address ${APPC_ACCOUNT_ADDRESS} \
   --private-key ${APPC_PRIVATE_KEY} \
   --rpc-url ${KATANA_L3_RPC}

sozo deploy 0x03653979a4d0bcd57a755a32a182d0650d9cd45cd3ff3be28a20c972e1c9c29c \
   --account-address ${APPC_ACCOUNT_ADDRESS} \
   --private-key ${APPC_PRIVATE_KEY} \
   --salt 0x1234 \
   --rpc-url ${KATANA_L3_RPC}

# Take note of the address and export it:
export APPC_MSG_SN_ADDRESS=0x00be8c1b5ddc2edacb375bc8734b8a96d618f8213df8bd531e60fa338c0aa429
```

## Setup Saya

Saya is the settlement orchestrator for the L3 appchain. It is responsible for:
- Generating the trace running SNOS on the blocks of the L3 appchain.
- Generating the proof of the trace for every block of the L3 appchain (using Herodotus in production).
- Sending the proof to Starknet to the facts registry contract.
- Updating the appchain state with the new state root by calling the Piltover contract.

In mock mode, Saya will generate the trace, but no actual proof will be generated. Since the proof can be
mocked from the trace.

To work, Saya requires an account on the settlement chain (Starknet L2) to advance the state, which makes the Saya command looking like this:

```bash
# In an other terminal.
RUST_LOG=saya=debug \
   saya persistent start \
   --settlement-rpc ${KATANA_L2_RPC} \
   --settlement-piltover-address ${PILTOVER_ADDRESS} \
   --settlement-account-address 0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec \
   --settlement-account-private-key 0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912 \
   --rollup-rpc ${KATANA_L3_RPC} \
   --mock-snos-from-pie \
   --mock-layout-bridge-program-hash 0x43c5c4cc37c4614d2cf3a833379052c3a38cd18d688b617e2c720e8f941cb8
```

It is using the `saya=debug` to make sure you have the logs to see messages being processed.

The command is still a bit verbose, but it will be simplified in the future.
The settlement account is for now a default account on Katana, you can adjust depending on your configuration.

The options `--mock-snos-from-pie` and `--mock-layout-bridge-program-hash` are used to mock the SNOS and the layout bridge program hash,
to avoid having to generate the proof.

Saya should start ingesting the blocks of the L3 appchain, and run them through the pipeline to generate the proof and update the appchain state.
It should take only few seconds per block, the trace might take a bit more time depending on the block size.

**Important to notes:**
- Saya generated a `saya.db` file. If you want to rerun a fresh start, you will have to remove this file.
Otherwise, if you kill Saya, and restart it, it will anyway check the appchain state on the L2 sequencer and recover from the latest proven block.

- Don't forget that Katana as a persistent state available with a database. If you want to resume to a known state, the `saya.db` must match the state of your appchain too!

- If you restart the L3 from scratch, but not the L2, then Saya will not be able to recover (which is expected), since you may generate a new history of blocks on the L3 that doesn't match the state of the L2.

## Sending messages L2 -> L3

Let's use the `sn_msg` contract to send a message to the `appc_msg_sn` contract.

Remember that we need to target a contract on the appchain and provide the selector of the function to call.
This entrypoint **must** be marked as `#[l1_handler]` to be able to receive messages from Starknet via a `L1HandlerTransaction`.

```bash
sozo invoke \
   --rpc-url ${KATANA_L2_RPC} \
   --katana-account katana0 \
   ${SN_MSG_ADDRESS} send_message ${APPC_MSG_SN_ADDRESS} selector:msg_handler_value 888

# Or use an other value instead of 888 to trigger an error.
```

The appchain should receive the message as soon as the L2 block has been mined and the L3 sequencer is processing it.
You will see a transaction being executed on the L3 sequencer logs.

```bash
2025-11-28 23:19:18.639 +00:00  INFO messaging: L1Handler transaction added to the pool. tx_hash=0x52eb64c0d996bb1c049225a110f1a24e35ed0d2972cbeeac39e188abc2590d4 contract_address=0xbe8c1b5ddc2edacb375bc8734b8a96d618f8213df8bd531e60fa338c0aa429 selector=0x5421de947699472df434466845d68528f221a52fce7ad2934c5dae2e1f1cdc calldata=0x3c87be0be4d0ff385fe08d8beb0a1c2861c8133d54dfa73e27b082748b5c2a1, 0x378
```

## Sending messages L3 -> L2

To send messages from the appchain to Starknet, we need to use the `send_message_to_l1_syscall` syscall in an appchain contract.

In our example, this is the `send_message` entrypoint of the `appc_msg_sn`.

```bash
sozo invoke \
   --rpc-url ${KATANA_L3_RPC} \
   --account-address ${APPC_ACCOUNT_ADDRESS} \
   --private-key ${APPC_PRIVATE_KEY} \
   ${APPC_MSG_SN_ADDRESS} send_message ${SN_MSG_ADDRESS} 111
```

I you've enabled the `RUST_LOG` for debug for Katana, you should see the message in the logs.

Now, we need to wait Saya picking up the block with this transaction, and advance the state of the appchain
on the L2 sequencer.

Saya should display the message if you have enabled the `saya=debug` logs.
```bash
[2025-11-29T00:20:00Z DEBUG saya_core::settlement::piltover] Message to L1: MessageToL1 { from_address: 0xbe8c1b5ddc2edacb375bc8734b8a96d618f8213df8bd531e60fa338c0aa429, to_address: 0x3c87be0be4d0ff385fe08d8beb0a1c2861c8133d54dfa73e27b082748b5c2a1, payload: [0x6f] }
```

You should see something like this in the Saya logs:
```bash
[2025-11-28T15:37:43Z INFO  saya_core::orchestrator::persistent] Chain advanced to new block block_number=6 transaction_hash=0x448978cbfa2a47b900aae794694bc8119f625c93143891303b0339a210631d3
```

After you see the state being advanced, you can consume the message on Starknet by calling the `consume_message_value` entrypoint.

```bash
sozo invoke \
   --rpc-url ${KATANA_L2_RPC} \
   --katana-account katana0 \
   ${SN_MSG_ADDRESS} consume_message_value ${APPC_MSG_SN_ADDRESS} 111
```

Note that you must provide the exact same value that was sent from the appchain to the Starknet contract, and the same contract address.
Otherwise, the hash of the message will not be found in the storage of the piltover contract, and the transaction will revert.

Piltover keeps a counter for each message hash, so the exact same message may be sent multiple times from the L3 to the L2, that's perfectly valid.
However, once the counter reaches 0, the message can't be consumed, and you will get an error like this when the transaction is executed:
```bash
[...] ('INVALID_MESSAGE_TO_CONSUME').
```

# Conclusion

This is it! This is exactly how Starknet messages with Ethereum. But here, we are at the appchain level, where Saya replicates the exact same flow as the one done on Starknet.

It is important in the design of your application that you take in account the asymmetry of the flow.

When sending messages from L2 to L3, it's almost instantaneouly processed by the appchain, and the entrypoint you marked as `#[l1_handler]` can be called.

But when sending messages from L3 to L2, the message is not processed immediately. It will be picked up by the proving pipeline (Saya in the present case), and once and only once the block has been proven, the message can be consumed by the Starknet contract.

The state advancement of the appchain on Starknet (including the messages) is managed by the Piltover contract (and Saya is sending transactions to the Piltover contract to advance the state).
