// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "src/ContractMsg.sol";

/**
   Deploys only the ContractMsg.
*/
contract Deploy is Script {
    function setUp() public {}

    function run() public{
        uint256 deployerPrivateKey = vm.envUint("ACCOUNT_PRIVATE_KEY");
        address snMessagingAddress = vm.envAddress("SN_MESSAGING_ADDRESS");

        string memory json = "contract_msg_deploy";

        vm.startBroadcast(deployerPrivateKey);

        address contractMsg = address(new ContractMsg(snMessagingAddress));
        vm.serializeString(json, "contractMsg_address", vm.toString(contractMsg));

        vm.stopBroadcast();

        string memory data = vm.serializeBool(json, "success", true);

        string memory localLogs = "./logs/";
        vm.createDir(localLogs, true);
        vm.writeJson(data, string.concat(localLogs, "contract_msg_deploy.json"));
    }
}
