use starknet::ContractAddress;

#[starknet::interface]
pub trait ISavingBox<T> {
    fn get_samount(self: @T) -> u256;
    fn get_number_of_payments(self: @T) -> u256;
    fn get_payment_interval(self: @T) -> u256;
    fn get_start_time(self: @T) -> u64;
    fn change_samount(ref self: T, new_samount: u256);
    fn register(ref self: T);
    fn get_registered_count(self: @T) -> u32;
    fn get_registered_address(self: @T, index: u32) -> ContractAddress;
}

#[starknet::contract]
mod SavingBox {
    use super::ISavingBox;
    use starknet::{
        ContractAddress,
        get_caller_address,
        get_block_timestamp,
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess}
    };

    #[storage]
    struct Storage {
        save_amount: u256,
        number_of_payments: u256,
        payment_interval: u256,
        start_time: u64,
        registered_addresses: LegacyMap<u32, ContractAddress>,
        registered_count: u32,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        save_amount: u256,
        number_of_payments: u256,
        payment_interval: u256
    ) {
        // Store the initial parameters
        self.save_amount.write(save_amount);
        self.number_of_payments.write(number_of_payments);
        self.payment_interval.write(payment_interval);
        
        // Store deployment timestamp
        self.start_time.write(get_block_timestamp());
        // Initialize registration count
        self.registered_count.write(0);
    }

    #[abi(embed_v0)]
    impl samountImpl of ISavingBox<ContractState> {
        fn get_samount(self: @ContractState) -> u256 {
            self.save_amount.read()
        }

        fn get_number_of_payments(self: @ContractState) -> u256 {
            self.number_of_payments.read()
        }

        fn get_payment_interval(self: @ContractState) -> u256 {
            self.payment_interval.read()
        }

        fn get_start_time(self: @ContractState) -> u64 {
            self.start_time.read()
        }

        fn change_samount(ref self: ContractState, new_samount: u256) {
            self.save_amount.write(new_samount);
        }

        fn register(ref self: ContractState) {
            let caller = get_caller_address();
            let current_count = self.registered_count.read();
            
            // Store the new address
            self.registered_addresses.write(current_count, caller);
            // Increment the counter
            self.registered_count.write(current_count + 1);
        }

        fn get_registered_count(self: @ContractState) -> u32 {
            self.registered_count.read()
        }

        fn get_registered_address(self: @ContractState, index: u32) -> ContractAddress {
            assert(index < self.registered_count.read(), 'Index out of bounds');
            self.registered_addresses.read(index)
        }
    }
}