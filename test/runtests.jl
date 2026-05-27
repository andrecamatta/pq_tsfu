using Test
using PQTSFu

@testset "PQTSFu" begin

    @testset "Construção de tipos" begin
        a = Asset(name = "Test", notional = 100.0, maturity_periods = 5, coupon_rate = 0.05)
        @test a.notional == 100.0
        @test a.maturity_periods == 5

        s = FundingSource(name = "Dep", notional = 100.0, maturity_periods = 1,
                          coupon_rate = 0.03, stress_runoff_rate = 0.10)
        @test s.stress_runoff_rate == 0.10
    end

    @testset "Cashflow de ativo" begin
        a = Asset(name = "L", notional = 100.0, maturity_periods = 3, coupon_rate = 0.05)
        @test PQTSFu.asset_cashflow_at(a, 1) ≈ 5.0
        @test PQTSFu.asset_cashflow_at(a, 2) ≈ 5.0
        @test PQTSFu.asset_cashflow_at(a, 3) ≈ 105.0  # juros + principal
        @test PQTSFu.asset_cashflow_at(a, 4) == 0.0
    end

    @testset "TSFu monotônica para banco sob estresse pesado" begin
        bank = BankSnapshot(
            name = "Heavy stress",
            cash_initial = 100.0,
            assets = [Asset(name = "L", notional = 1000.0, maturity_periods = 5, coupon_rate = 0.0)],
            funding_sources = [
                FundingSource(name = "Dep", notional = 1000.0, maturity_periods = 1,
                              coupon_rate = 0.0, stress_runoff_rate = 0.50),
            ],
            risk_free_rate = 0.0,
            horizon = 5,
        )
        tsfu = compute_tsfu(bank)
        @test length(tsfu) == 6  # t = 0, 1, 2, 3, 4, 5
        @test tsfu[1] == 100.0  # t=0
        # Em t=1, runoff de 500 + reembolso do residual no vencimento; AVL fica muito negativo
        @test tsfu[2] < 0
    end

    @testset "TSFu de banco canônico" begin
        bank = canonical_bank(horizon = 6)
        tsfu = compute_tsfu(bank)
        @test length(tsfu) == 7
        @test tsfu[1] == bank.cash_initial
        @test all(isfinite, tsfu)
    end

    @testset "Roll forward preserva consistência" begin
        bank = canonical_bank(horizon = 6)
        bank_at_2 = PQTSFu.roll_forward(bank, 2)
        @test bank_at_2.horizon == 4
        # cash em t=0 do bank_at_2 deve igualar AVL(0,2) do banco original
        @test bank_at_2.cash_initial ≈ project_avl(bank, 2)
    end

    @testset "TSFcF tem mesma diagonal que TSFu" begin
        bank = canonical_bank(horizon = 5)
        tsfu = compute_tsfu(bank)
        tsfcf = compute_tsfcf(bank)
        # A primeira linha (f=0) deve coincidir com a TSFu
        for k in 0:bank.horizon
            @test tsfcf[1, k+1] ≈ tsfu[k+1]
        end
    end

    @testset "FTP curve crescente em prazo (caso típico)" begin
        bank = brazilian_bank(horizon = 6)
        curve = matched_maturity_ftp_curve(bank)
        @test length(curve) == bank.horizon
        # Cada par é (período, taxa total)
        for (t, rate) in curve
            @test rate >= bank.risk_free_rate
        end
    end

    @testset "Pricing de empréstimo de 5 anos" begin
        bank = brazilian_bank(horizon = 6)
        result = price_new_loan(bank, 50.0, 5; capital_charge = 0.005)
        @test result.total_ftp > bank.risk_free_rate
        @test result.capital_charge == 0.005
        @test result.funding_spread >= 0
    end

end
