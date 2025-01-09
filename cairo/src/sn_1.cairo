//! Simple contract to send / consume message from appchain, to be deployed on Starknet.

use starknet::ContractAddress;

#[starknet::interface]
trait Isn_1<T> {
    fn send_message(ref self: T, to_address: ContractAddress, selector: felt252, value: felt252);
    fn consume_message_value(ref self: T, value: felt252);
}

#[starknet::contract]
mod sn_1 {
    use super::Isn_1;
    use starknet::ContractAddress;
    use piltover::messaging::interface::{IMessagingDispatcher, IMessagingDispatcherTrait};

    #[storage]
    struct Storage {
        // Piltover address to send and consume messages.
        messaging_contract: ContractAddress,
        // Whitelisted appchain contract address to accept messages from.
        appchain_contract: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, messaging_contract: ContractAddress, appchain_contract: ContractAddress) {
        self.messaging_contract.write(messaging_contract);
        self.appchain_contract.write(appchain_contract);
    }

    #[abi(embed_v0)]
    impl Isn_1Impl of Isn_1<ContractState> {
        /// Sends a message with the given value.
        fn send_message(
            ref self: ContractState, to_address: ContractAddress, selector: felt252, value: felt252,
        ) {
            let messaging = IMessagingDispatcher {
                contract_address: self.messaging_contract.read()
            };

            messaging.send_message_to_appchain(to_address, selector, array![value].span(),);
        }

        /// Consume a message registered by the appchain.
        fn consume_message_value(
            ref self: ContractState, value: felt252,
        ) {
            let messaging = IMessagingDispatcher {
                contract_address: self.messaging_contract.read()
            };

            // Will revert in case of failure if the message is not registered
            // as consumable.
            let _msg_hash = messaging.consume_message_from_appchain(
                self.appchain_contract.read(),
                array![value].span(),
            );

            // msg successfully consumed, we can proceed and process the data
            // in the payload.
        }
    }
}
