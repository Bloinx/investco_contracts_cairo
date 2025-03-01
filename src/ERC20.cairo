use starknet::ContractAddress;

#[starknet::interface]
trait IERC20<TContractState> {
    // camelCase functions
    fn getName(self: @TContractState) -> felt252;
    fn getSymbol(self: @TContractState) -> felt252;
    fn getDecimals(self: @TContractState) -> u8;
    fn getTotalSupply(self: @TContractState) -> u256;
    fn balanceOf(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn increaseAllowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decreaseAllowance(ref self: TContractState, spender: ContractAddress, subtracted_value: u256);
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    
    // snake_case functions
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn transfer_from(ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(ref self: TContractState, spender: ContractAddress, subtracted_value: u256);
}

#[starknet::contract]
mod ERC20 {
    use zeroable::Zeroable;
    use starknet::get_caller_address;
    use starknet::contract_address_const;
    use starknet::ContractAddress;

    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: LegacyMap::<ContractAddress, u256>,
        allowances: LegacyMap::<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }
    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name_: felt252,
        symbol_: felt252,
        decimals_: u8,
    ) {
        self.name.write(name_);
        self.symbol.write(symbol_);
        self.decimals.write(decimals_);
    }

    #[abi(embed_v0)]
    impl IERC20Impl of super::IERC20<ContractState> {
        // camelCase implementations
        fn getName(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn getSymbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn getDecimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn getTotalSupply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self.transfer_helper(sender, recipient, amount);
            true
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self.spend_allowance(sender, caller, amount);
            self.transfer_helper(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
            true
        }

        fn increaseAllowance(ref self: ContractState, spender: ContractAddress, added_value: u256) {
            let caller = get_caller_address();
            self.approve_helper(
                caller,
                spender,
                self.allowances.read((caller, spender)) + added_value
            );
        }

        fn decreaseAllowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) {
            let caller = get_caller_address();
            self.approve_helper(
                caller,
                spender,
                self.allowances.read((caller, spender)) - subtracted_value
            );
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.total_supply.write(self.total_supply.read() + amount);
            self.emit(
                Event::Transfer(
                    Transfer {
                        from: contract_address_const::<0>(),
                        to: recipient,
                        value: amount
                    }
                )
            );
        }
        
        // snake_case implementations
        fn get_name(self: @ContractState) -> felt252 {
            self.getName()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.getSymbol()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.getDecimals()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.getTotalSupply()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balanceOf(account)
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            self.transferFrom(sender, recipient, amount)
        }

        fn increase_allowance(ref self: ContractState, spender: ContractAddress, added_value: u256) {
            self.increaseAllowance(spender, added_value)
        }

        fn decrease_allowance(ref self: ContractState, spender: ContractAddress, subtracted_value: u256) {
            self.decreaseAllowance(spender, subtracted_value)
        }
    }

    #[generate_trait]
    impl StorageImpl of StorageTrait {
        fn transfer_helper(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self.balances.write(sender, self.balances.read(sender) - amount);
            self.balances.write(recipient, self.balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            let ONES_MASK = 0xffffffffffffffffffffffffffffffff_u128;
            let is_unlimited_allowance = current_allowance.low == ONES_MASK
                && current_allowance.high == ONES_MASK;
            if !is_unlimited_allowance {
                self.approve_helper(owner, spender, current_allowance - amount);
            }
        }

        fn approve_helper(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!spender.is_zero(), 'ERC20: approve from 0');
            self.allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }
    }
}