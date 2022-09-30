module escrow::Escrow {
    #[test_only]
    use std::signer;
    // #[test_only]
    // use aptos_std::debug;

    use aptos_framework::coin;
    use aptos_std::type_info;

    //
    // Errors
    //
    // 1 - 5
    const ERR_BALANCE_NOT_ENOUGHT: u64 = 1;
    const ERR_INVALID_COIN: u64 = 2;

    struct Escrow<phantom T, phantom Y> has key {
        offered_coin: coin::Coin<T>,
        expected_coin: coin::Coin<Y>,
        offered_amount: u64,
        expected_amount: u64,
    }

    fun coin_address<CoinType>(): address {
        let type_info = type_info::type_of<CoinType>();
        type_info::account_address(&type_info)
    }

    public entry fun offer<T, Y>(offeror: &signer, offered_amount: u64, expected_amount: u64) {
        let offered_coin = coin::withdraw<T>(offeror, offered_amount);
        move_to(offeror, Escrow<T, Y>{ expected_amount, offered_coin, expected_coin: coin::zero<Y>(), offered_amount })
    }

    public entry fun take_offer<T, Y>(taker: &signer, offeror: address) acquires Escrow {
        let taker_addr = signer::address_of(taker);
        let escrow = borrow_global_mut<Escrow<T, Y>>(offeror);

        let taker_coin = coin::withdraw<Y>(taker, escrow.expected_amount);
        coin::merge<Y>(&mut escrow.expected_coin, taker_coin);

        let offered_coin = coin::extract<T>(&mut escrow.offered_coin, escrow.offered_amount);
        coin::deposit<T>(taker_addr, offered_coin);
    }

    #[test_only]
    struct FakeCoinA {}

    #[test_only]
    struct FakeCoinB {}

    #[test_only]
    use aptos_framework::managed_coin;
    #[test_only]
    use aptos_framework::account::create_account_for_test;

    #[test_only]
    fun init_coin<T>(source: &signer) {
        managed_coin::initialize<T>(source, b"FakeToken", b"FAKE", 9, false);
    }

    #[test]
    fun test_offer() acquires Escrow {
        let root = create_account_for_test(@escrow);
        let offeror = create_account_for_test(@0xC0FEEE);

        init_coin<FakeCoinA>(&root);
        init_coin<FakeCoinB>(&root);

        coin::register<FakeCoinA>(&offeror);
        let addr = signer::address_of(&offeror);
        managed_coin::mint<FakeCoinA>(&root, addr, 1000);

        offer<FakeCoinA, FakeCoinB>(&offeror, 1000, 50);
        let expected_amount = borrow_global<Escrow<FakeCoinA, FakeCoinB>>(addr).expected_amount;
        assert!(expected_amount == 50, 0);

        let offered_amount = borrow_global<Escrow<FakeCoinA, FakeCoinB>>(addr).offered_amount;
        assert!(offered_amount == 1000, 0);

        let after_offer_balance = coin::balance<FakeCoinA>(addr);
        assert!(after_offer_balance == 0, 0);
    }

    #[test]
    fun test_take_offer() acquires Escrow {
        let root = create_account_for_test(@escrow);
        let offeror = create_account_for_test(@0xC0FEEE);

        init_coin<FakeCoinA>(&root);
        init_coin<FakeCoinB>(&root);

        coin::register<FakeCoinA>(&offeror);
        let addr = signer::address_of(&offeror);
        managed_coin::mint<FakeCoinA>(&root, addr, 1000);

        offer<FakeCoinA, FakeCoinB>(&offeror, 1000, 50);
        let expected_amount = borrow_global<Escrow<FakeCoinA, FakeCoinB>>(addr).expected_amount;
        assert!(expected_amount == 50, 0);

        let offered_amount = borrow_global<Escrow<FakeCoinA, FakeCoinB>>(addr).offered_amount;
        assert!(offered_amount == 1000, 0);

        let after_offer_balance = coin::balance<FakeCoinA>(addr);
        assert!(after_offer_balance == 0, 0);

        // ---
        let taker = create_account_for_test(@0xCAFE);

        coin::register<FakeCoinA>(&taker);
        coin::register<FakeCoinB>(&taker);
        coin::register<FakeCoinB>(&offeror);

        let taker_addr = signer::address_of(&taker);
        let offeror_addr = signer::address_of(&offeror);
        managed_coin::mint<FakeCoinB>(&root, taker_addr, 50);

        take_offer<FakeCoinA, FakeCoinB>(&taker, offeror_addr);

        let after_trade_taker = coin::balance<FakeCoinA>(taker_addr);
        assert!(after_trade_taker == 1000, 01);

        let escrow = borrow_global<Escrow<FakeCoinA, FakeCoinB>>(addr);
        assert!(coin::value<FakeCoinB>(&escrow.expected_coin) == 50, 0);
    }
}
