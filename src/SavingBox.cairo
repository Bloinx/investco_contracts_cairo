use starknet::ContractAddress;

#[starknet::interface]
pub trait ISavingBox<T> {
    // Contract parameter getters
    fn get_samount(self: @T) -> u256;
    fn get_number_of_payments(self: @T) -> u64;
    fn get_payment_interval(self: @T) -> u64;
    fn get_start_time(self: @T) -> u64;

    // User management functions
    fn register_user(ref self: T);
    fn get_user_data(self: @T, user_address: ContractAddress) -> (u256, u64, u64, bool);
    fn get_registered_users(self: @T) -> Array<ContractAddress>;
    fn real_payment(self: @T) -> u64;
    fn pay(ref self: T);
}

#[starknet::contract]
mod SavingBox {
    use super::ISavingBox;
    use core::array::ArrayTrait;
    use starknet::contract_address::ContractAddress;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{get_block_timestamp, get_caller_address};

    #[storage]
    struct Storage {
        save_amount: u256,
        number_of_payments: u64,
        payment_interval: u64,
        start_time: u64,
        registered_users: Map<ContractAddress, bool>,
        available_savings_map: Map<ContractAddress, u256>,
        valid_payments_map: Map<ContractAddress, u64>,
        late_payments_map: Map<ContractAddress, u64>,
        user_count: u32,
        user_list: Map<u32, ContractAddress>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        save_amount: u256,
        number_of_payments: u64,
        payment_interval: u64
    ) {
        self.save_amount.write(save_amount);
        self.number_of_payments.write(number_of_payments);
        self.payment_interval.write(payment_interval);
        self.start_time.write(get_block_timestamp());
        self.user_count.write(0);
    }

    #[abi(embed_v0)]
    impl SavingBox of ISavingBox<ContractState> {
        fn get_samount(self: @ContractState) -> u256 {
            self.save_amount.read()
        }

        fn get_number_of_payments(self: @ContractState) -> u64 {
            self.number_of_payments.read()
        }

        fn get_payment_interval(self: @ContractState) -> u64 {
            self.payment_interval.read()
        }

        fn get_start_time(self: @ContractState) -> u64 {
            self.start_time.read()
        }

        fn register_user(ref self: ContractState) {
            let caller: ContractAddress = get_caller_address();
            let is_registered = self.registered_users.read(caller);
            
            if !is_registered {
                self.registered_users.write(caller, true);
                self.available_savings_map.write(caller, 0);
                self.valid_payments_map.write(caller, 0);
                self.late_payments_map.write(caller, 0);
                
                // Add user to the list
                let current_count = self.user_count.read();
                self.user_list.write(current_count, caller);
                self.user_count.write(current_count + 1);
            }
        }

        fn get_user_data(self: @ContractState, user_address: ContractAddress) -> (u256, u64, u64, bool) {
            (
                self.available_savings_map.read(user_address),
                self.valid_payments_map.read(user_address),
                self.late_payments_map.read(user_address),
                self.registered_users.read(user_address)
            )
        }

        fn get_registered_users(self: @ContractState) -> Array<ContractAddress> {
            let mut users = ArrayTrait::new();
            let count = self.user_count.read();
            let mut i: u32 = 0;
            
            loop {
                if i >= count {
                    break;
                }
                users.append(self.user_list.read(i));
                i += 1;
            };
            
            users
        }

        fn real_payment(self: @ContractState) -> u64 {
            let current_time = get_block_timestamp();
            let start_time = self.start_time.read();
            let payment_interval = self.payment_interval.read();
            
            if current_time < start_time {
                return 0;
            }

            let time_diff = current_time - start_time;
            let expected_payments = time_diff / payment_interval;
            expected_payments

            // Cap at maximum number of payments
            //let max_payments = self.number_of_payments.read();
            //if expected_payments > max_payments {
            //    max_payments
            //} else {
            //    expected_payments
            //}
        }

        fn pay(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.registered_users.read(caller), 'User not registered');

            let save_amount = self.save_amount.read();
            let expected_payments = self.real_payment();
            let current_savings = self.available_savings_map.read(caller);
            let expected_savings = save_amount * expected_payments.into();

            // Check if user is up to date
            assert(current_savings < expected_savings, 'Already up to date');

            // Update savings
            self.available_savings_map.write(caller, current_savings + save_amount);

            // Update payment counters based on status
            if current_savings == expected_savings - save_amount {
                // User is making payment on time
                let current_valid = self.valid_payments_map.read(caller);
                self.valid_payments_map.write(caller, current_valid + 1);
            } else {
                // User is late with payments
                let current_late = self.late_payments_map.read(caller);
                self.late_payments_map.write(caller, current_late + 1);
            }
        }
    }
}