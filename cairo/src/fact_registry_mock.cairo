//! Code related to mock the fact registry capabilities
//! required for appchain.cairo to successfuly use integrity
//! in a mocked environment.

#[derive(Drop, Serde)]
pub struct VerificationListElement {
    pub verification_hash: felt252,
    pub security_bits: u32,
    pub verifier_config: VerifierConfiguration,
}

#[derive(Drop, Serde)]
pub struct VerifierConfiguration {
    pub layout: felt252,
    pub hasher: felt252,
    pub stone_version: felt252,
    pub cairo_version: felt252,
}

#[starknet::interface]
pub trait IFactRegistry<T> {
    fn get_all_verifications_for_fact_hash(
        self: @T, fact: felt252,
    ) -> Array<VerificationListElement>;
}

/// Integrity utils used in appchain.cairo uses `get_all_verifications_for_fact_hash` under the
/// hood.
/// We then mock the behavior of this function defined here:
/// <https://github.com/HerodotusDev/integrity/blob/f3beacec88cd225a88945649627f3c3ea2232077/src/lib_utils.cairo#L59>
#[starknet::contract]
pub mod fact_registry_mock {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl FactRegistryImplMock of super::IFactRegistry<ContractState> {
        fn get_all_verifications_for_fact_hash(
            self: @ContractState, fact: felt252,
        ) -> Array<super::VerificationListElement> {
            let verification_list_element = super::VerificationListElement {
                verification_hash: 1,
                security_bits: 60,
                verifier_config: super::VerifierConfiguration {
                    layout: 1, hasher: 1, stone_version: 1, cairo_version: 1,
                },
            };
            array![verification_list_element]
        }
    }
}
