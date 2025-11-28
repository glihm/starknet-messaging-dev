# Starknet L3 appchain messaging local development with Saya and Katana

This repository aims at giving the detailed steps to locally work
on Starknet messaging with `Katana` and `Saya` in the context of L3 appchain on the top of Starknet.

## Requirements

Please before start, install:

- [scarb](https://docs.swmansion.com/scarb/) to build cairo contracts.
- [sozo](https://github.com/dojoengine/sozo) installed via ASDF is the easiest way to go.
- [katana](https://github.com/dojoengine/katana) you must currently use this [very specific version 1.7.0-snos.2](https://github.com/dojoengine/katana/pkgs/container/katana/579546066?tag=v1.7.0-snos.2) via docker for the L3 sequencer. For the L2 sequencer, you can use the latest stable version of Katana.
- [saya](https://github.com/dojoengine/saya) TODO -> make a release + ASDF @glihm.

**CURRENTLY WIP ON SNOS ISSUE**

Issue on SNOS about gas when we have at least 1 message for L2 in a L3 block.
To reproduce:

Debug setup:
Katana L2 started with latest stable `1.7.0`.
Katana L3 started on the branch `feat/update-gen-and-statefull-compr` on commit `95323f35b43e392e1e3988a9136737edfdd36ddd`.
Saya on branch `feat/update-to-new-snos` on commit `8dc989fc01b479051c4c553f5ed366a4b85e846c`.
For sozo to execute the command, use sozo `1.8.3` to have access to declare/deploy/invoke commands.

And then follow the tutorial until the moment when sending a message L3 -> L2.

**--**


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

1. When going L2 -> L3, a contract on Starknet sends a message, which emits an event that the L3 sequencer will pick up and execute a `L1HandlerTransaction` almost immediately after the block containing this event has been mined. This doesn't require any proof to be generated. To be executed by such method, the contract must have an entrypoint marked as `#[l1_handler]`.
2. When going L3 -> L2, a contract on the appchain sends a message (using the `send_message_to_l1_syscall`). When the L3 sequencer will execute a transaction with this syscall, the message will be included in the block. Then, when the block execution is replayed and proven by the prover (done by Saya), the message will then be part of the proof output. Finally, when the proof will be submitted and verified on Starknet, this is where the message will be ready to be consumed via the core contract (Piltover).

In order to shorten the development cycle, Saya can be used to mock the proof generation and piltover will use a mock verifier. Doing so, the L2-L3 messaging flow can be tested locally in few seconds without having to wait for the proof generation (which is the longest part of the flow).

## Contracts

Few contracts involved here:

1. `fact_registry_mock`: Mock contract to be deployed on Starknet (L2) to mock the fact registry. Since we are not using actual proofs, we need to mock the fact registry to have a valid proof.
2. `sn_msg`: Contract to be deployed on Starknet (L2) to receive/send messages to the appchain (L3).
3. `appc_msg_sn`: Contract to be deployed on the appchain (L3) to receive/send messages to Starknet (L2).

As you notice, piltover is not listed here. This is because Katana includes an `init` command that does it for us. Since Piltover requires specific configuration to match the generated proofs, we let Katana handling this automatically.

Let's head to the `cairo` folder and compile the contracts:
```bash
cd cairo
scarb build
```

## Setup the L2 (Starknet)

Let's start by starting the sequencer acting like Starknet (L2). You can use the latest stable version of Katana for this one.

```bash
katana --dev --dev.no-fee --http.port 50000
```
```bash
export KATANA_L2_RPC=http://0.0.0.0:50000
```

Let's then declare and deploy the mocked fact registry contract:
```bash
sozo declare target/dev/sn_msg_dev_fact_registry_mock.contract_class.json \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

sozo deploy 0x01d42b549cf7a09fc7ffdd176a0addf6e7d26d81678240597e58f1103952faf8 \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

# Update to your address depending on your Katana version it may change.
export FACT_REGISTRY_MOCK_ADDRESS=0x03eb0d510d1238120bf7f9d176faafe0c7066797a86be985855952f87769d3bd
```

Now, let's use Katana init to deploy and configure piltover for us. For this action, you must use the Katana version specific to the L3 appchain (v1.7.0-snos.2).

TODO: change for docker once published.
```bash
# The account address and private key matches default katana accounts if you have used a recent
# version of Katana for the Starknet L2 we just started.
~/cgg/katana/target/release/katana init \
--settlement-chain ${KATANA_L2_RPC} \
--id katana-l3 \
--settlement-account-private-key 0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912 \
--settlement-account-address 0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec \
--settlement-facts-registry ${FACT_REGISTRY_MOCK_ADDRESS}

# TODO: docker with output-path for the chain config.

# Take note of the piltover address and export it (katana uses an internal salt for this contract, it will change between runs. Use a volume for Katana DB if you want to maintain the contract).
export PILTOVER_ADDRESS=0x264db9b9a80aae61c01371d0fc0ec751b80f96b6e861bdcf61e608673681178
```

Now that we have the piltover address, we can deploy the `sn_msg` contract on Starknet:
```bash
sozo declare target/dev/sn_msg_dev_sn_msg.contract_class.json \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

sozo deploy 0x011dceea1eeb800a2a87454e424acb9158b5c649687d92a045c3eb6b73a182db \
   --constructor-calldata ${PILTOVER_ADDRESS} \
   --katana-account katana0 \
   --rpc-url ${KATANA_L2_RPC}

# Take note of the address and export it:
export SN_MSG_ADDRESS=0x01efae3ea0375876819cfe418a95d740f2880f061efd6ae29f5651043ac5f8f3
```

## Setup the L3 (Appchain)

If you've noticed, we've used a `--id` flag for Katana. This saves a file locally with the chain configuration, which includes the messaging configuration. We then use the `--chain` flag to use this file (please note this is a different concept than `--chain-id`).

```bash
~/cgg/katana/target/release/katana --chain katana-l3 --http.port 51000

# For more logs, you can use:
RUST_LOG="katana=info,rpc=info,node=info,messaging=trace,executor=trace,pool=trace" ~/cgg/katana/target/release/katana --chain katana-l3 --http.port 51000

# And then export the RPC URL:
export KATANA_L3_RPC=http://0.0.0.0:51000
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

We can now declare and deploy the `appc_msg_sn` contract on the L3:
```bash
sozo declare target/dev/sn_msg_dev_appc_msg_sn.contract_class.json \
   --account-address ${APPC_ACCOUNT_ADDRESS} \
   --private-key ${APPC_PRIVATE_KEY} \
   --rpc-url ${KATANA_L3_RPC}

sozo deploy 0x03653979a4d0bcd57a755a32a182d0650d9cd45cd3ff3be28a20c972e1c9c29c \
   --account-address ${APPC_ACCOUNT_ADDRESS} \
   --private-key ${APPC_PRIVATE_KEY} \
   --rpc-url ${KATANA_L3_RPC}

# Take note of the address and export it:
export APPC_MSG_SN_ADDRESS=0x06de7c50591935a933c6f38daf80aa99aa1ee4e037e4f14d28f046b581da6617
```

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

```bash
cargo run --bin saya -- persistent start --settlement-piltover-address 0x264db9b9a80aae61c01371d0fc0ec751b80f96b6e861bdcf61e608673681178 --settlement-account-address 0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec --settlement-account-private-key 0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912 --mock-snos-from-pie --rollup-rpc http://127.0.0.1:51000 --settlement-rpc http://127.0.0.1:50000 --atlantic-key local --mock-layout-bridge-program-hash 0x43c5c4cc37c4614d2cf3a833379052c3a38cd18d688b617e2c720e8f941cb8
```
