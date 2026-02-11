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
- [sozo](https://github.com/dojoengine/sozo) installed via ASDF is the easiest way to go and you must use at least version `1.8.3` to have access to declare/deploy/invoke commands (`1.8.6` is recommended).
   ```bash
   asdf plugin add sozo https://github.com/dojoengine/asdf-sozo.git
   asdf install sozo 1.8.6
   ```
- [saya](https://github.com/dojoengine/saya) installed via ASDF:
   ```bash
   asdf plugin add saya https://github.com/dojoengine/asdf-saya.git
   asdf install saya 0.2.2
   ```
- [katana](https://github.com/dojoengine/katana) you must currently use this [very specific version 1.7.0-snos.4](https://github.com/dojoengine/katana/pkgs/container/katana/679535262?tag=v1.7.0-snos.4) via docker for the L3 sequencer. For the L2 sequencer, you can use the latest stable version of Katana.

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

In the new flow, Saya already has the compatible piltover version pre-compiled and ready to use.

The canonical flow to have the appchain state and messages updates on Starknet is the following:

1. When going L2 -> L3, a contract on Starknet sends a message by calling the core contract (Piltover), which emits an event that the L3 sequencer will pick up and execute a `L1HandlerTransaction` almost immediately after the block containing this event has been mined. This doesn't require any proof to be generated. To be executed by such method, the contract on L3 must have an entrypoint marked as `#[l1_handler]`.
2. When going L3 -> L2, a contract on the appchain (L3) sends a message (using the `send_message_to_l1_syscall`). When the L3 sequencer will execute a transaction with this syscall, the message will be included in the block. Then, when the block execution is replayed and proven by the prover (done by Saya), the message will then be part of the proof output. Finally, when the proof will be submitted and verified on Starknet, this is where the message will be ready to be consumed via the core contract (Piltover) on L2.

In order to shorten the development cycle, Saya can be used to mock the proof generation and piltover will use a mocked fact registry. Doing so, the L2-L3 messaging flow can be tested locally in few seconds without having to wait for the proof generation (which is the longest part of the flow).

## Contracts

Few contracts involved here:

1. `fact_registry_mock`: Mock contract to be deployed on Starknet (L2) to mock the fact registry. Since we are not using actual proofs, we need to mock the fact registry to have a valid proof.
2. `sn_msg`: Contract to be deployed on Starknet (L2) to receive/send messages to the appchain (L3).
3. `appc_msg_sn`: Contract to be deployed on the appchain (L3) to receive/send messages to Starknet (L2).

As you notice, piltover is not listed here. This is because Saya includes `core-contract` commands that deploy and configure piltover for us. Since Piltover requires specific configuration to match the generated proofs, we let Saya handling this.

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

Let's setup some environment variables for the commands to follow, using default Katana first account.
```bash
export SETTLEMENT_ACCOUNT_ADDRESS=0x127fd5f1fe78a71f8bcd1fec63e3fe2f0486b6ecd5c86a0466c3a21fa5cfcec
export SETTLEMENT_ACCOUNT_PRIVATE_KEY=0xc5b2fcab997346f3ea1c00b002ecf6f382c5f9c9659a3894eb783c5320f912
export SETTLEMENT_RPC_URL=http://localhost:50000
export SETTLEMENT_CHAIN_ID=KATANA
```

Let's then declare and deploy the mocked fact registry contract.
```bash
saya core-contract declare-and-deploy-fact-registry-mock --salt 0x0

export FACT_REGISTRY_ADDRESS=0x3eb0d510d1238120bf7f9d176faafe0c7066797a86be985855952f87769d3bd
```

Now let's use Saya again to declare, deploy and configure the core contract..

```bash
saya core-contract declare
saya core-contract deploy --salt 0x0

# You should see an output like:
# [2026-02-10T22:45:37Z INFO  saya::core_contract::cli] Core contract address: 0x1c8a55203cd99a6bfaf7cd91ae2ad953eff67b584826edab1857ca2e3c5db5d
# You must also take not of the block number at which the core contract was deployed, we will use it later.

export CORE_CONTRACT_ADDRESS=0x1c8a55203cd99a6bfaf7cd91ae2ad953eff67b584826edab1857ca2e3c5db5d
export CORE_CONTRACT_DEPLOYED_BLOCK=4

# katana-l3 is the chain is that will be used to run the appchain.
saya core-contract setup-program --chain-id katana-l3
```

Now that we have the piltover address, we can deploy the `sn_msg` contract on Starknet:
```bash
sozo declare target/dev/sn_msg_dev_sn_msg.contract_class.json \
   --katana-account katana0 \
   --rpc-url ${SETTLEMENT_RPC_URL}

sozo deploy 0x011dceea1eeb800a2a87454e424acb9158b5c649687d92a045c3eb6b73a182db \
   --constructor-calldata ${CORE_CONTRACT_ADDRESS} \
   --salt 0x1234 \
   --katana-account katana0 \
   --rpc-url ${SETTLEMENT_RPC_URL}

# Take note of the address and export it, it will change between runs since Piltover address is
# changing too (and is passed to the constructor of the sn_msg contract).
export SN_MSG_ADDRESS=0x05caadeae8dae02b47180f7e26a999d35e63be5f0fe773c7ebf93461fa25a513
```

## Setup the L3 (Appchain)

To setup the L3 appchain, you must use the SNOS version of Katana v1.7.0-snos.4. From docker, or binary compiled from the commit `de6274a48b4c7d28c26a9aa1cc162da717f9e6f1`.

Use `katana init` command to create an appchain chain spec file. We will use a chain id name of `katana-l3`.

```bash
katana init \
  --settlement-chain ${SETTLEMENT_RPC_URL} \
  --id katana-l3 \
  --settlement-contract ${CORE_CONTRACT_ADDRESS} \
  --settlement-contract-deployed-block ${CORE_CONTRACT_DEPLOYED_BLOCK} \
  --settlement-facts-registry ${FACT_REGISTRY_ADDRESS}
```

If you've noticed, we've used a `--id` flag for Katana `init` command. This saves a file locally with the chain configuration, which includes the messaging configuration. We then use the `--chain` flag to use this file (note that this is a different concept than `--chain-id`).

Open a fresh terminal (and not the one used with all the environment variables exported) and start the Katana L3 sequencer.
```bash
katana --chain katana-l3 --http.port 51000 --db-dir /tmp/katana-l3

# For more logs, you can add this before the binary execution:
RUST_LOG="katana=info,rpc=info,node=info,messaging=trace,executor=trace,pool=trace" \
katana --chain katana-l3 --http.port 51000 --db-dir /tmp/katana-l3

# Or use the `--env` flag to set the environment variable:
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
   --settlement-rpc ${SETTLEMENT_RPC_URL} \
   --settlement-piltover-address ${CORE_CONTRACT_ADDRESS} \
   --settlement-account-address ${SETTLEMENT_ACCOUNT_ADDRESS} \
   --settlement-account-private-key ${SETTLEMENT_ACCOUNT_PRIVATE_KEY} \
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

**Notes on posting DA to Celestia:**
- To enable the DA posting to Celestia, you must start Saya with those additional arguments:
```bash
--celestia-rpc <CELESTIA_RPC_URL> \
--celestia-token <CELESTIA_TOKEN> \
--celestia-namespace <CELESTIA_NAMESPACE>
```

By setting those, Saya will automatically post the DA to Celestia, and the DA cursor will be settle on Piltover.

You will see a log like this in the Saya logs:
```bash
[2026-02-11T02:44:54Z INFO  saya_core::data_availability::celestia] Blob posted on Celestia. block_number=5 celestia_block=10034708 namespace="AAAAAAAAAAAAAAAAAAAAAAAAAHNheWFnbGlobTE=" commitment="ee0ee3ec708f650580f9ea82246030748f07ccc50a522e42a5f8ce118fddceae"
```

In order to retrieve the blob, you can use [Celenium](https://mocha-4.celenium.io), and you can paste your namespace id into the search bar.

To compute a namespace id, just use Saya subcommand:
```bash
saya celestia namespace testns1
```
This will output:
```bash
Version: 0
Hex: 0x00000000000000000000000000000000000000000000746573746e7331
Base64: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAHRlc3RuczE=
Namespace ID (last 10 bytes): 0x000000746573746e7331
Raw bytes length: 29
```
Just use the base64 `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAHRlc3RuczE=` of the namespace id to search it in Celenium.

You can also use the `blob-get` from Saya if you want to do it from the terminal:
```bash
saya celestia blob-get \
   --rpc-url <CELESTIA_RPC_URL> \
   --height <HEIGHT> \
   --commitment <COMMITMENT> \
   --namespace-base64 <NAMESPACE_BASE64> \
   --auth-token <CELESTIA_TOKEN>
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
