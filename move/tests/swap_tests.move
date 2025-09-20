#[test_only]
module suiworld::swap_tests {
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
    
    use sui::coin::{Self, Coin, mint_for_testing, burn_for_testing};
    use sui::sui::SUI;
    use suiworld::swap::{Self};
    use suiworld::token::{Self, SWT, SwapPool};

    const TRADER1: address = @0x31;
    const TRADER2: address = @0x32;
    const LP_PROVIDER: address = @0x41;

    const INITIAL_SUI_LIQUIDITY: u64 = 1_000_000_000_000; // 1000 SUI
    const INITIAL_SWT_LIQUIDITY: u64 = 10_000_000_000_000; // 10,000 SWT

    // ======== Helper Functions ========

    fun init_test_scenario(): Scenario {
        test::begin(@0x0)
    }

    fun setup_swap_pool(scenario: &mut Scenario) {
        // Initialize token module (creates SwapPool)
        next_tx(scenario, LP_PROVIDER);

        // Get initial pool state
        let pool = test::take_shared<SwapPool>(scenario);
        assert!(swap::get_sui_reserve(&pool) == 0, 999);
        assert!(swap::get_swt_reserve(&pool) == 70_000_000_000_000, 999); // Initial 70M SWT
        test::return_shared(pool);
    }

    fun add_initial_liquidity(scenario: &mut Scenario) {
        next_tx(scenario, LP_PROVIDER);

        let mut pool = test::take_shared<SwapPool>(scenario);

        // Create test coins for initial liquidity
        let sui_coin = mint_for_testing<SUI>(INITIAL_SUI_LIQUIDITY, ctx(scenario));
        let swt_coin = mint_for_testing<SWT>(INITIAL_SWT_LIQUIDITY, ctx(scenario));

        swap::add_liquidity(
            &mut pool,
            sui_coin,
            swt_coin,
            ctx(scenario)
        );

        test::return_shared(pool);
    }

    // ======== Swap SUI to SWT Tests ========

    #[test]
    fun test_swap_sui_to_swt_success() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let sui_amount = 1_000_000_000; // 1 SUI
            let sui_coin = mint_for_testing<SUI>(sui_amount, ctx(&mut scenario));

            // Get initial reserves
            let sui_reserve = swap::get_sui_reserve(&pool);
            let swt_reserve = swap::get_swt_reserve(&pool);

            let swt_coin = swap::swap_sui_to_swt(
                &mut pool,
                sui_coin,
                0, // No minimum for test
                ctx(&mut scenario)
            );

            // Verify output amount is reasonable (should be less than input due to fees)
            let swt_output = coin::value(&swt_coin);
            assert!(swt_output > 0, 999);

            // Verify reserves updated correctly
            assert!(swap::get_sui_reserve(&pool) == sui_reserve + sui_amount, 999);
            assert!(swap::get_swt_reserve(&pool) == swt_reserve - swt_output, 999);

            burn_for_testing(swt_coin);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::swap::ESlippageExceeded)]
    fun test_swap_sui_to_swt_slippage_protection() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let sui_amount = 1_000_000_000;
            let sui_coin = mint_for_testing<SUI>(sui_amount, ctx(&mut scenario));

            // Set unrealistic minimum output
            let min_swt_out = 100_000_000_000; // Way too high

            let swt_coin = swap::swap_sui_to_swt(
                &mut pool,
                sui_coin,
                min_swt_out,
                ctx(&mut scenario)
            );

            burn_for_testing(swt_coin);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = suiworld::swap::EZeroAmount)]
    fun test_swap_zero_sui_fails() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let zero_coin = mint_for_testing<SUI>(0, ctx(&mut scenario));

            let swt_coin = swap::swap_sui_to_swt(
                &mut pool,
                zero_coin,
                0,
                ctx(&mut scenario)
            );

            burn_for_testing(swt_coin);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    // ======== Swap SWT to SUI Tests ========

    #[test]
    fun test_swap_swt_to_sui_success() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, TRADER2);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let swt_amount = 10_000_000_000; // 10,000 SWT
            let swt_coin = mint_for_testing<SWT>(swt_amount, ctx(&mut scenario));

            let sui_reserve = swap::get_sui_reserve(&pool);
            let swt_reserve = swap::get_swt_reserve(&pool);

            let sui_coin = swap::swap_swt_to_sui(
                &mut pool,
                swt_coin,
                0,
                ctx(&mut scenario)
            );

            // Verify output is reasonable and reserves updated
            let sui_output = coin::value(&sui_coin);
            assert!(sui_output > 0, 999);
            assert!(swap::get_swt_reserve(&pool) == swt_reserve + swt_amount, 999);
            assert!(swap::get_sui_reserve(&pool) == sui_reserve - sui_output, 999);

            burn_for_testing(sui_coin);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    // ======== AMM Formula Tests ========

    #[test]
    fun test_constant_product_maintained() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        // Get initial k value
        let mut pool = test::take_shared<SwapPool>(&mut scenario);
        let initial_k = swap::get_sui_reserve(&pool) * swap::get_swt_reserve(&pool);
        test::return_shared(pool);

        // Perform multiple swaps
        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            // Swap 1: SUI to SWT
            let sui_coin = mint_for_testing<SUI>(1_000_000_000, ctx(&mut scenario));
            let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));
            burn_for_testing(swt_coin);

            // Check k is maintained (with small tolerance for fees)
            let k_after_swap1 = swap::get_sui_reserve(&pool) * swap::get_swt_reserve(&pool);
            assert!(k_after_swap1 >= initial_k, 0); // k should increase due to fees

            test::return_shared(pool);
        };

        next_tx(&mut scenario, TRADER2);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            // Swap 2: SWT to SUI
            let swt_coin = mint_for_testing<SWT>(5_000_000_000, ctx(&mut scenario));
            let sui_coin = swap::swap_swt_to_sui(&mut pool, swt_coin, 0, ctx(&mut scenario));
            burn_for_testing(sui_coin);

            // Check k is still maintained
            let k_after_swap2 = swap::get_sui_reserve(&pool) * swap::get_swt_reserve(&pool);
            assert!(k_after_swap2 >= initial_k, 1);

            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    fun test_swap_fee_calculation() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let input_amount = 1_000_000_000; // 1 SUI
            let sui_reserve_before = swap::get_sui_reserve(&pool);
            let swt_reserve_before = swap::get_swt_reserve(&pool);

            // Perform swap
            let sui_coin = mint_for_testing<SUI>(input_amount, ctx(&mut scenario));
            let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));

            let output_amount = coin::value(&swt_coin);
            burn_for_testing(swt_coin);

            // Verify fee is applied (output should be less than theoretical no-fee amount)
            let theoretical_output = (input_amount * swt_reserve_before) / (sui_reserve_before + input_amount);

            // Calculate fee impact
            let fee_impact = theoretical_output - output_amount;
            let expected_fee = (theoretical_output * 30) / 10000; // 0.3% fee

            // Output should be less due to fees
            assert!(fee_impact >= expected_fee - 100 && fee_impact <= expected_fee + 100, 0);

            test::return_shared(pool);
        };

        test::end(scenario);
    }

    // ======== Liquidity Tests ========

    #[test]
    fun test_add_liquidity_balanced() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, LP_PROVIDER);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let initial_sui = swap::get_sui_reserve(&pool);
            let initial_swt = swap::get_swt_reserve(&pool);

            // Add proportional liquidity
            let sui_to_add = 100_000_000_000; // 100 SUI
            let swt_to_add = (sui_to_add * initial_swt) / initial_sui;

            let sui_coin = mint_for_testing<SUI>(sui_to_add, ctx(&mut scenario));
            let swt_coin = mint_for_testing<SWT>(swt_to_add, ctx(&mut scenario));

            swap::add_liquidity(&mut pool, sui_coin, swt_coin, ctx(&mut scenario));

            // Verify reserves increased proportionally
            assert!(swap::get_sui_reserve(&pool) == initial_sui + sui_to_add, 999);
            assert!(swap::get_swt_reserve(&pool) == initial_swt + swt_to_add, 999);

            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    fun test_remove_liquidity() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        // Add more liquidity first
        next_tx(&mut scenario, LP_PROVIDER);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let sui_coin = mint_for_testing<SUI>(500_000_000_000, ctx(&mut scenario));
            let swt_coin = mint_for_testing<SWT>(5_000_000_000_000, ctx(&mut scenario));

            swap::add_liquidity(&mut pool, sui_coin, swt_coin, ctx(&mut scenario));
            test::return_shared(pool);
        };

        // Remove liquidity
        next_tx(&mut scenario, LP_PROVIDER);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let initial_sui = swap::get_sui_reserve(&pool);
            let initial_swt = swap::get_swt_reserve(&pool);

            let sui_to_remove = 100_000_000_000;
            let swt_to_remove = 1_000_000_000_000;

            swap::remove_liquidity(
                &mut pool,
                sui_to_remove,
                swt_to_remove,
                LP_PROVIDER,
                ctx(&mut scenario)
            );

            assert!(swap::get_sui_reserve(&pool) == initial_sui - sui_to_remove, 999);
            assert!(swap::get_swt_reserve(&pool) == initial_swt - swt_to_remove, 999);

            test::return_shared(pool);
        };

        // Verify LP received the removed tokens
        {
            let sui_coin = test::take_from_sender<Coin<SUI>>(&mut scenario);
            let swt_coin = test::take_from_sender<Coin<SWT>>(&mut scenario);

            assert!(coin::value(&sui_coin) == 100_000_000_000, 999);
            assert!(coin::value(&swt_coin) == 1_000_000_000_000, 999);

            burn_for_testing(sui_coin);
            burn_for_testing(swt_coin);
        };

        test::end(scenario);
    }

    // ======== Edge Cases ========

    #[test]
    fun test_large_swap_price_impact() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            // Very large swap (50% of pool)
            let large_amount = swap::get_sui_reserve(&pool) / 2;
            let sui_coin = mint_for_testing<SUI>(large_amount, ctx(&mut scenario));

            let initial_price = swap::get_swt_reserve(&pool) / swap::get_sui_reserve(&pool);

            let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));

            let final_price = swap::get_swt_reserve(&pool) / swap::get_sui_reserve(&pool);

            // Price should have moved significantly
            assert!(final_price < (initial_price * 75) / 100, 0); // Price dropped >25%

            burn_for_testing(swt_coin);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    fun test_minimum_liquidity() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);

        // Try to add very small liquidity (should still work)
        next_tx(&mut scenario, LP_PROVIDER);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let sui_coin = mint_for_testing<SUI>(1001, ctx(&mut scenario)); // Just above minimum
            let swt_coin = mint_for_testing<SWT>(1001, ctx(&mut scenario));

            swap::add_liquidity(&mut pool, sui_coin, swt_coin, ctx(&mut scenario));

            assert!(swap::get_sui_reserve(&pool) == 1001, 999);
            // SWT reserve already has initial 70M

            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    fun test_sequential_swaps() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);
        add_initial_liquidity(&mut scenario);

        // Perform many sequential swaps
        let mut i = 0;
        while (i < 10) {
            let trader = if (i == 0) @0x5000 else if (i == 1) @0x5001 else if (i == 2) @0x5002 else if (i == 3) @0x5003 else if (i == 4) @0x5004 else @0x5005;
            next_tx(&mut scenario, trader);
            {
                let mut pool = test::take_shared<SwapPool>(&mut scenario);

                if (i % 2 == 0) {
                    // Even: SUI to SWT
                    let sui_coin = mint_for_testing<SUI>(100_000_000, ctx(&mut scenario));
                    let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));
                    burn_for_testing(swt_coin);
                } else {
                    // Odd: SWT to SUI
                    let swt_coin = mint_for_testing<SWT>(1_000_000_000, ctx(&mut scenario));
                    let sui_coin = swap::swap_swt_to_sui(&mut pool, swt_coin, 0, ctx(&mut scenario));
                    burn_for_testing(sui_coin);
                };

                test::return_shared(pool);
            };
            i = i + 1;
        };

        // Pool should still be functional
        next_tx(&mut scenario, @0x0);
        {
            let pool = test::take_shared<SwapPool>(&mut scenario);
            assert!(swap::get_sui_reserve(&pool) > 0, 0);
            assert!(swap::get_swt_reserve(&pool) > 0, 1);
            test::return_shared(pool);
        };

        test::end(scenario);
    }

    #[test]
    fun test_price_discovery() {
        let mut scenario = init_test_scenario();
        setup_swap_pool(&mut scenario);

        // Start with unbalanced pool
        next_tx(&mut scenario, LP_PROVIDER);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            let sui_coin = mint_for_testing<SUI>(1_000_000_000_000, ctx(&mut scenario)); // 1000 SUI
            let swt_coin = mint_for_testing<SWT>(100_000_000_000_000, ctx(&mut scenario)); // 100,000 SWT

            swap::add_liquidity(&mut pool, sui_coin, swt_coin, ctx(&mut scenario));

            // Initial price: 100 SWT per SUI
            let initial_price = swap::get_swt_reserve(&pool) / swap::get_sui_reserve(&pool);
            assert!(initial_price == 100, 999);

            test::return_shared(pool);
        };

        // Arbitrage trades should move price
        next_tx(&mut scenario, TRADER1);
        {
            let mut pool = test::take_shared<SwapPool>(&mut scenario);

            // Buy SWT when it's cheap
            let sui_coin = mint_for_testing<SUI>(50_000_000_000, ctx(&mut scenario));
            let swt_coin = swap::swap_sui_to_swt(&mut pool, sui_coin, 0, ctx(&mut scenario));

            burn_for_testing(swt_coin);

            // Price should have increased (less SWT per SUI)
            let new_price = swap::get_swt_reserve(&pool) / swap::get_sui_reserve(&pool);
            assert!(new_price < 100, 0);

            test::return_shared(pool);
        };

        test::end(scenario);
    }
}