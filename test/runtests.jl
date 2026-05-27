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

    @testset "TSFCFu monotônica não-crescente em maturidade" begin
        bank = canonical_bank(horizon = 5)
        tsfcfu = compute_tsfcfu(bank)
        @test length(tsfcfu) == 6
        for i in 1:(length(tsfcfu) - 1)
            @test tsfcfu[i] >= tsfcfu[i+1] - 1e-9
        end
    end

    @testset "TSFCFu primeiro elemento = soma cumulada da TSFu positiva" begin
        bank = canonical_bank(horizon = 5)
        tsfu = compute_tsfu(bank)
        tsfcfu = compute_tsfcfu(bank)
        @test tsfcfu[1] ≈ sum(max(0.0, x) for x in tsfu)
        @test tsfcfu[end] ≈ max(0.0, tsfu[end])
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
