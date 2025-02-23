use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transferFrom(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
pub trait ISavingBox<T> {
    // Contract parameter getters
    fn get_samount(self: @T) -> u256;
    fn get_number_of_payments(self: @T) -> u64;
    fn get_payment_interval(self: @T) -> u64;
    fn get_start_time(self: @T) -> u64;

    // User management functions
    fn get_user_data(self: @T, user_address: ContractAddress) -> (u256, u64, u64, bool);
    fn get_registered_users(self: @T) -> Array<ContractAddress>;
    fn advance_payment(ref self: T);
    fn get_expected_payments(self: @T, timestamp: u64) -> u64;
    fn get_current_payment(self: @T) -> u64;
    fn pay(ref self: T);

    //Withdrawal functions
    fn early_withdraw(ref self: T, num_payments: u64);
    fn withdraw(ref self: T);
    fn get_withdraw_fee(self: @T) -> u64;
    fn get_total_fees_collected(self: @T) -> u256;

    fn get_token_address(self: @T) -> ContractAddress;
}

#[starknet::contract]
mod SavingBox {
    use super::{ISavingBox, IERC20Dispatcher, IERC20DispatcherTrait};
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
        current_payment: u64,
        withdraw_fee: u64,  //Percentage fee for early withdrawal (e.g., 10 for 10%)
        total_fees_collected: u256,  // Track total fees collected from early withdrawals
        registered_users: Map<ContractAddress, bool>,
        available_savings_map: Map<ContractAddress, u256>,
        valid_payments_map: Map<ContractAddress, u64>,
        late_payments_map: Map<ContractAddress, u64>,
        user_count: u32,
        user_list: Map<u32, ContractAddress>,
        has_withdrawn: Map<ContractAddress, bool>,  //Track if user has withdrawn
        token_address: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        save_amount: u256,
        number_of_payments: u64,
        payment_interval: u64,
        withdraw_fee: u64,
        token_address: ContractAddress,
    ) {
        assert(withdraw_fee <= 50, 'Fee must be <= 50%');
        self.save_amount.write(save_amount);
        self.number_of_payments.write(number_of_payments);
        self.payment_interval.write(payment_interval);
        self.start_time.write(get_block_timestamp());
        self.current_payment.write(1);
        self.withdraw_fee.write(withdraw_fee);
        self.total_fees_collected.write(0);
        self.user_count.write(0);
        self.token_address.write(token_address);
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

        fn get_current_payment(self: @ContractState) -> u64 {
            self.current_payment.read()
        }

        fn get_withdraw_fee(self: @ContractState) -> u64 {
            self.withdraw_fee.read()
        }

        fn get_total_fees_collected(self: @ContractState) -> u256 {
            self.total_fees_collected.read()
        }

        fn get_token_address(self: @ContractState) -> ContractAddress {
            self.token_address.read()
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

        fn advance_payment(ref self: ContractState){
            let current_time = get_block_timestamp();
            let start_time = self.start_time.read();
            let payment_interval = self.payment_interval.read();
            let time_diff = current_time - start_time;
            let expected_payments = 1 + (time_diff / payment_interval);
            let current_payment = self.current_payment.read();
            
            if expected_payments > current_payment {
                self.current_payment.write(expected_payments);
            }
        }

        fn get_expected_payments(self: @ContractState, timestamp: u64) -> u64 {
            let start_time = self.start_time.read();
            let payment_interval = self.payment_interval.read();
            let max_payments = self.number_of_payments.read();
            
            if timestamp < start_time {
                return 0;
            }

            let time_diff = timestamp - start_time;
            let expected_payments = 1 + (time_diff / payment_interval);

            expected_payments
            
            //if expected_payments > max_payments {
            //    max_payments
            //} else {
            //    expected_payments
            //}
        }

        fn pay(ref self: ContractState) {
            //advance payment
            let current_time = get_block_timestamp();
            let start_time = self.start_time.read();
            let payment_interval = self.payment_interval.read();
            let time_diff = current_time - start_time;
            let expected_payments = 1 + (time_diff / payment_interval);
            let current_payment = self.current_payment.read();
            
            if expected_payments > current_payment {
                self.current_payment.write(expected_payments);
            }

            let caller = get_caller_address();
            let is_registered = self.registered_users.read(caller);
            
            //let expected_payments = self.current_payment.read();
            
            // If user is not registered and this is their first payment
            if !is_registered {
                assert(expected_payments <= 1, 'Too late to start saving');
                
                // Register the user
                self.registered_users.write(caller, true);
                self.available_savings_map.write(caller, 0);
                self.valid_payments_map.write(caller, 0);
                self.late_payments_map.write(caller, 0);
                
                // Add user to the list
                let current_count = self.user_count.read();
                self.user_list.write(current_count, caller);
                self.user_count.write(current_count + 1);
            }

            let save_amount = self.save_amount.read();
            let current_savings = self.available_savings_map.read(caller);
            let expected_savings = save_amount * expected_payments.into();

            // Check if user has already made the maximum number of payments
            let total_payments_made = self.valid_payments_map.read(caller) + self.late_payments_map.read(caller);
            let number_of_payments = self.number_of_payments.read();
            assert(total_payments_made >= number_of_payments, 'Max number of payments');

            // Transfer tokens from user to contract
            let token = IERC20Dispatcher { contract_address: self.token_address.read() };
            assert(
                token.transferFrom(caller, starknet::get_contract_address(), save_amount),
                'Token transfer failed'
            );

            // Update savings
            self.available_savings_map.write(caller, current_savings + save_amount);

            // Update payment counters based on status
            if current_savings >= expected_savings - save_amount {
                // User is making payment on time
                let current_valid = self.valid_payments_map.read(caller);
                self.valid_payments_map.write(caller, current_valid + 1);
            } else {
                // User is late with payments
                let current_late = self.late_payments_map.read(caller);
                self.late_payments_map.write(caller, current_late + 1);
            }
        }

        fn early_withdraw(ref self: ContractState, num_payments: u64) {
            let caller = get_caller_address();
            assert(self.registered_users.read(caller), 'User not registered');
            assert(!self.has_withdrawn.read(caller), 'Already withdrawn');
            
            let current_payments = self.current_payment.read();
            assert(current_payments <= self.number_of_payments.read(), 'Regular withdrawal available');
            
            let current_savings = self.available_savings_map.read(caller);
            let valid_payments = self.valid_payments_map.read(caller);
            
            // Verify user has enough valid payments to withdraw
            assert(valid_payments >= num_payments, 'Not enough valid payments');
            
            // Calculate withdrawal amount with fee
            let withdraw_amount = self.save_amount.read() * num_payments.into();
            let fee_percentage = self.withdraw_fee.read();
            let fee_amount = (withdraw_amount * fee_percentage.into()) / 100_u256;
            let final_amount = withdraw_amount - fee_amount;
            
            // Update user's data
            self.valid_payments_map.write(caller, valid_payments - num_payments);
            self.available_savings_map.write(caller, current_savings - withdraw_amount);
            self.total_fees_collected.write(self.total_fees_collected.read() + fee_amount);
            
            // Mark as withdrawn if all funds are taken
            if current_savings == withdraw_amount {
                self.has_withdrawn.write(caller, true);
            }
            
            // Transfer tokens to user
            let token = IERC20Dispatcher { contract_address: self.token_address.read() };
            assert(
                token.transfer(caller, final_amount),
                'Token transfer failed'
            );
        }

        fn withdraw(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.registered_users.read(caller), 'User not registered');
            assert(!self.has_withdrawn.read(caller), 'Already withdrawn');
            
            let current_payments = self.current_payment.read();
            assert(current_payments >= self.number_of_payments.read(), 'Too early to withdraw');
            
            // Calculate user's share of the total fees
            let total_fees = self.total_fees_collected.read();
            let user_valid_payments = self.valid_payments_map.read(caller);
            
            // Calculate total valid payments across all users
            let mut total_valid_payments: u64 = 0;
            let user_count = self.user_count.read();
            let mut i: u32 = 0;
            
            loop {
                if i >= user_count {
                    break;
                }
                let user = self.user_list.read(i);
                if !self.has_withdrawn.read(user) {
                    total_valid_payments += self.valid_payments_map.read(user);
                }
                i += 1;
            };
            
            // Calculate user's earnings from fees
            let user_fee_share = if total_valid_payments > 0 {
                (total_fees * user_valid_payments.into()) / total_valid_payments.into()
            } else {
                0
            };
            
            // Calculate total withdrawal amount
            let savings = self.available_savings_map.read(caller);
            let total_amount = savings + user_fee_share;
            
            // Update state
            self.has_withdrawn.write(caller, true);
            self.available_savings_map.write(caller, 0);
            
            // Transfer tokens to user
            let token = IERC20Dispatcher { contract_address: self.token_address.read() };
            assert(
                token.transfer(caller, total_amount),
                'Token transfer failed'
            );
        }
    }
}