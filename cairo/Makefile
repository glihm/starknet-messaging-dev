##
# Messaging Makefile.
#
# Only for local testing on Katana and Anvil as addresses are pre-computed.
ACCOUNT_FILE=./katana-0.json
ACCOUNT_ADDR=0xb3ff441a68610b30fd5e2abbf3a1548eb6ba6f3559f2862bf2dc757e5828ca
ACCOUNT_PRIVATE_KEY=0x2bbf4f9fd0bbb2e60b0316c1fe0b76cf7a4d0198bd493ced9b8df2a3a24d68a

# The address of testing contract on Anvil, it's fixed as Anvil seed is not modified
# from default.
L1_CONTRACT_ADDR=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512

# The deployed address on Katana is also pre-computed. So if you change the contract,
# please consider changing this value too as the contract class will change.
CONTRACT_MSG_ADDR=0x02defe8eeb8e8c1cf59de8ba1a6844e8781d27e2ee20439204757b338f8ae74c
CONTRACT_MSG_CLASS_HASH=0x051a7b3565ab605475512178fc157d743c9a394242ab60207a6932a25e087456

value = 1

data = 1 2

OPTS := --account ${ACCOUNT_FILE} \
	--rpc http://0.0.0.0:5050 \
	--private-key ${ACCOUNT_PRIVATE_KEY}

# Important to use a salt for deploy to ensure constant address between runs.
setup_for_messaging:
	scarb build
	starkli declare target/dev/messaging_tuto_contract_msg.contract_class.json ${OPTS}
	starkli deploy --salt 0x1234 ${CONTRACT_MSG_CLASS_HASH} ${OPTS}

send_msg_value_l1:
	starkli invoke ${CONTRACT_MSG_ADDR} send_message_value ${L1_CONTRACT_ADDR} $(value) ${OPTS}

send_msg_struct_l1:
	starkli invoke ${CONTRACT_MSG_ADDR} send_message_struct ${L1_CONTRACT_ADDR} $(data) ${OPTS}
