//! Simple contract to send / consume message from an appchain, to be deployed on Starknet.
//!
//! If you are working with an appchain, you will want some contracts on Starknet that are able
//! to send and consume messages from the appchain. This is an example of such a contract.
//!
//! The messages at the protocol level and state of the appchain are managed by the piltover core contract,
//! which is also deployed on Starknet.
//! This contract will typically interact with the piltover core contract to send and consume messages.
//!
//! In this demo contract, the addresses we send messages to or receive messages from are exposed as
//! functions parameters. In real life scenario, you may want to store the addresses in the contract storage,
//! and only expose entrypoints useful to your users and the messages are related to the business logic of your app.

use starknet::ContractAddress;

#[starknet::interface]
trait ISnMsg<T> {
    /// Sends a message with the given value to the given contract address (an appchain contract).
    ///
    /// # Arguments
    ///
    /// * `to_address` - Contract address of the appchain contract to send the message to.
    /// * `selector` - Selector of the function to call on the appchain contract.
    /// * `value` - Value to be sent in the payload.
    fn send_message(ref self: T, to_address: ContractAddress, selector: felt252, value: felt252);

    /// Consumes a message with the given value received from the given contract address (an appchain contract).
    ///
    /// As you note, we must know in advance which contract we are expecting the message from, and what is the
    /// payload of the message (in this case, a single felt252 value).
    ///
    /// # Arguments
    ///
    /// * `from_address` - Contract address of the appchain contract that sent the message.
    /// * `value` - Expected value in the payload.
    fn consume_message_value(ref self: T, from_address: ContractAddress, value: felt252);
}

#[starknet::contract]
mod sn_msg {
    use super::ISnMsg;
    use starknet::ContractAddress;
    use piltover::messaging::interface::{IMessagingDispatcher, IMessagingDispatcherTrait};

    #[storage]
    struct Storage {
        // Piltover address to send and consume messages.
        messaging_contract: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, messaging_contract: ContractAddress) {
        self.messaging_contract.write(messaging_contract);
    }

    #[abi(embed_v0)]
    impl ISnMsgImpl of ISnMsg<ContractState> {
        fn send_message(
            ref self: ContractState, to_address: ContractAddress, selector: felt252, value: felt252,
        ) {
            let messaging = IMessagingDispatcher {
                contract_address: self.messaging_contract.read()
            };

            messaging.send_message_to_appchain(to_address, selector, array![value].span(),);
        }

        fn consume_message_value(
            ref self: ContractState, from_address: ContractAddress, value: felt252,
        ) {
            let messaging = IMessagingDispatcher {
                contract_address: self.messaging_contract.read()
            };

            // Will revert in case of failure if the message is not registered
            // as consumable.
            let _msg_hash = messaging.consume_message_from_appchain(
                from_address,
                array![value].span(),
            );

            // msg successfully consumed, we can proceed and process the data
            // in the payload and do what's needed depending on the business logic.
        }
    }
}
