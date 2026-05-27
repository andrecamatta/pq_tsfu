"""
    funding_curve_at(bank, t)

Para o período t no horizonte, calcula o spread efetivo de captação
implícito (sB médio ponderado) sobre as fontes que ainda estão ativas em
t. É a base para a curva de FTP por maturidade.

Em ambiente de estresse, fontes com maior runoff_rate contribuem mais
para o gap em t e portanto pesam mais na curva marginal.
"""
function funding_curve_at(bank::BankSnapshot, t::Int)
    rf = bank.risk_free_rate
    total_outflow = 0.0
    weighted_spread = 0.0
    for source in bank.funding_sources
        if t <= source.maturity_periods
            consumed_before = source.stress_runoff_rate * (t - 1)
            consumed_before = min(consumed_before, 1.0)
            outstanding = source.notional * (1 - consumed_before)
            spread = max(source.coupon_rate - rf, 0.0)
            total_outflow += outstanding
            weighted_spread += outstanding * spread
        end
    end
    return total_outflow > 0 ? weighted_spread / total_outflow : 0.0
end

"""
    matched_maturity_ftp_curve(bank)

Curva de FTP por maturidade conforme método Matched-Maturity Marginal
(Grant, 2011). Para cada bucket t, a taxa interna que a tesouraria cobra
das áreas de negócio em uma operação de prazo t é r_f + sB(t), onde
sB(t) é o spread efetivo derivado da TSFu vigente.

Retorna vetor com horizonte completo.
"""
function matched_maturity_ftp_curve(bank::BankSnapshot)
    rf = bank.risk_free_rate
    return [(t, rf + funding_curve_at(bank, t)) for t in 1:bank.horizon]
end

"""
    price_new_loan(bank, loan_notional, loan_maturity; capital_charge=0.0)

Preço interno (FTP) de um novo empréstimo de nominal `loan_notional` e
prazo `loan_maturity`. Usa a curva matched-maturity da TSFu para extrair
o sB aplicável e adiciona um capital_charge opcional.

Retorna NamedTuple com:
- `risk_free`: r_f vigente
- `funding_spread`: sB(loan_maturity) da curva
- `liquidity_premium`: incremento marginal pela deformação da TSFu
- `capital_charge`: parâmetro
- `total_ftp`: soma dos componentes
"""
function price_new_loan(
    bank::BankSnapshot,
    loan_notional::Float64,
    loan_maturity::Int;
    capital_charge::Float64 = 0.0,
)
    rf = bank.risk_free_rate
    funding_spread = funding_curve_at(bank, loan_maturity)

    # Deformação marginal da TSFu: simula adicionar o empréstimo ao banco
    # e mede a diferença no horizonte mais limitante
    new_asset = Asset(
        name = "Novo empréstimo",
        notional = loan_notional,
        maturity_periods = loan_maturity,
        coupon_rate = rf,
    )
    bank_with_loan = BankSnapshot(
        name = bank.name * " + novo loan",
        cash_initial = bank.cash_initial - loan_notional,  # caixa absorve o desembolso
        assets = vcat(bank.assets, [new_asset]),
        funding_sources = bank.funding_sources,
        risk_free_rate = rf,
        horizon = max(bank.horizon, loan_maturity),
    )
    bh_before = binding_horizon(bank)
    bh_after = binding_horizon(bank_with_loan)
    avl_deformation = bh_before.min_avl - bh_after.min_avl

    # Liquidity premium proxy: deformação relativa ao loan_notional
    liquidity_premium = max(avl_deformation / loan_notional, 0.0) * 0.01

    total = rf + funding_spread + liquidity_premium + capital_charge
    return (
        risk_free = rf,
        funding_spread = funding_spread,
        liquidity_premium = liquidity_premium,
        capital_charge = capital_charge,
        total_ftp = total,
        avl_deformation = avl_deformation,
    )
end

"""
    canonical_bank(; horizon=6)

Banco estilizado para demonstrar a TSFu, com mix balanceado de
captações de varejo, atacado curto e atacado longo.
"""
function canonical_bank(; horizon::Int = 6)
    return BankSnapshot(
        name = "Banco canônico",
        cash_initial = 50.0,
        assets = [
            Asset(name = "Empréstimo 5y", notional = 500.0, maturity_periods = 5, coupon_rate = 0.05),
            Asset(name = "Empréstimo 3y", notional = 300.0, maturity_periods = 3, coupon_rate = 0.04),
        ],
        funding_sources = [
            FundingSource(name = "Depósito varejo", notional = 400.0, maturity_periods = 1,
                          coupon_rate = 0.025, stress_runoff_rate = 0.05, is_stable = true),
            FundingSource(name = "CDB atacado 1y", notional = 200.0, maturity_periods = 1,
                          coupon_rate = 0.035, stress_runoff_rate = 0.20),
            FundingSource(name = "LF atacado 3y", notional = 150.0, maturity_periods = 3,
                          coupon_rate = 0.045, stress_runoff_rate = 0.10),
            FundingSource(name = "Capital próprio", notional = 100.0, maturity_periods = horizon,
                          coupon_rate = 0.0, stress_runoff_rate = 0.0, is_stable = true),
        ],
        risk_free_rate = 0.03,
        horizon = horizon,
    )
end

"""
    brazilian_bank(; horizon=6)

Banco brasileiro estilizado de S1 com mix de captação típico: CDB,
LF, depósitos em poupança/varejo, e capital próprio. Calibração de
runoff e spread alinhada ao mercado brasileiro (Selic ~11,5%).
"""
function brazilian_bank(; horizon::Int = 6)
    return BankSnapshot(
        name = "Banco S1 BR",
        cash_initial = 80.0,
        assets = [
            Asset(name = "Crédito imobiliário 5y", notional = 600.0, maturity_periods = 5, coupon_rate = 0.13),
            Asset(name = "Crédito empresarial 3y", notional = 400.0, maturity_periods = 3, coupon_rate = 0.14),
        ],
        funding_sources = [
            FundingSource(name = "Depósito poupança", notional = 350.0, maturity_periods = 1,
                          coupon_rate = 0.07, stress_runoff_rate = 0.05, is_stable = true),
            FundingSource(name = "CDB 1y FGC", notional = 250.0, maturity_periods = 1,
                          coupon_rate = 0.115, stress_runoff_rate = 0.10),
            FundingSource(name = "LF 2y", notional = 200.0, maturity_periods = 2,
                          coupon_rate = 0.125, stress_runoff_rate = 0.15),
            FundingSource(name = "LF 3y", notional = 150.0, maturity_periods = 3,
                          coupon_rate = 0.130, stress_runoff_rate = 0.10),
            FundingSource(name = "Capital próprio", notional = 130.0, maturity_periods = horizon,
                          coupon_rate = 0.0, stress_runoff_rate = 0.0, is_stable = true),
        ],
        risk_free_rate = 0.115,
        horizon = horizon,
    )
end
