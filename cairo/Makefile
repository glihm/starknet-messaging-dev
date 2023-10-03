##
# Messaging Makefile.
#
# Only for local testing on Katana and Anvil as addresses are pre-computed.
ACCOUNT_FILE=./katana-0.json
ACCOUNT_ADDR=0x517ececd29116499f4a1b64b094da79ba08dfd54a3edaa316134c41f8160973
ACCOUNT_PRIVATE_KEY=0x1800000000300000180000000000030000000000003006001800006600

# The address of testing contract on Anvil, it's fixed as Anvil seed is not modified
# from default.
L1_CONTRACT_ADDR=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

# The deployed address on Katana is also pre-computed. So if you change the contract,
# please consider changing this value too as the contract class will change.
CONTRACT_MSG_ADDR=0x0429a64d97c1422a37a09fc7406f35c264be59b744aaff5a79d59393eb1bc7e1
CONTRACT_MSG_CLASS_HASH=0x0429a64d97c1422a37a09fc7406f35c264be59b744aaff5a79d59393eb1bc7e1

OPTS := --account ${ACCOUNT_FILE} \
	--rpc http://0.0.0.0:5050 \
	--private-key ${ACCOUNT_PRIVATE_KEY}

# Important to use a salt for deploy to ensure constant address between runs.
setup_for_messaging:
	scarb build
	starkli declare target/dev/messaging_tuto_contract_msg.sierra.json ${OPTS}
	starkli deploy --salt 0x1234 ${CONTRACT_MSG_CLASS_HASH} ${OPTS}

send_msg_value_l1:
	starkli invoke ${CONTRACT_MSG_ADDR} send_message_value ${L1_CONTRACT_ADDR} $(value) ${OPTS}

send_msg_struct_l1:
	starkli invoke ${CONTRACT_MSG_ADDR} send_message_struct_l1 ${L1_CONTRACT_ADDR} $(data) ${OPTS}
