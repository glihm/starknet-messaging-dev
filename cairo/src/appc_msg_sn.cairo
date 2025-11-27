//! A simple contract to be deployed on the appchain
//! to send/receive messages to Starknet.
//!
//! This contract can send messages using the `send_message_to_l1_syscall`
//! syscall, but the l1 in this configuration is Starknet.
//!
//! In this demo contract, the addresses we send messages to or receive messages from are exposed as
//! functions parameters. In real life scenario, you may want to store the addresses in the contract
//! storage, and only expose entrypoints useful to your users and the messages are related to the
//! business logic of your app.
use starknet::ContractAddress;

#[starknet::interface]
trait IContractAppchain<T> {
    /// Sends a message to Starknet contract with a single felt252 value.
    /// This message will simply be registered on starknet to be then consumed
    /// manually.
    ///
    /// # Arguments
    ///
    /// * `to_address` - Contract address on Starknet.
    /// * `value` - Value to be sent in the payload.
    fn send_message(ref self: T, to_address: ContractAddress, value: felt252);
}

#[starknet::contract]
mod appc_msg_sn {
    use starknet::syscalls::send_message_to_l1_syscall;
    use starknet::{ContractAddress, SyscallResultTrait};
    use super::IContractAppchain;

    const WHITELISTED_VALUE: felt252 = 888;

    #[storage]
    struct Storage {}

    /// Handles a message received from Starknet.
    ///
    /// Only functions that are #[l1_handler] can
    /// receive message from Starknet, exactly as we do with L1 messaging.
    ///
    /// # Arguments
    ///
    /// * `from_address` - The Starknet contract sending the message.
    /// * `value` - Expected value in the payload (automatically deserialized).
    #[l1_handler]
    fn msg_handler_value(ref self: ContractState, from_address: felt252, value: felt252) {
        // Security check: since any contract on Starknet may send messages to the appchain, you
        // must check the sender address is a contract you allowed to send messages.
        // assert(from_address == ...);

        // An assert to demonstrate the behavior when an error occurs when receiving a message
        // from the base layer.
        assert(value == WHITELISTED_VALUE, 'Invalid value');
    }

    #[abi(embed_v0)]
    impl ContractAppChainImpl of IContractAppchain<ContractState> {
        fn send_message(ref self: ContractState, to_address: ContractAddress, value: felt252) {
            send_message_to_l1_syscall(to_address.into(), array![value].span()).unwrap_syscall();
        }
    }
}
