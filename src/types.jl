"""
    Asset

Ativo do banco com prazo definido. Os fluxos contratuais consistem em
juros pagos por período (`coupon_per_period` aplicado sobre o nominal) e o
principal pago no vencimento.

# Campos
- `name`: identificação
- `notional`: valor de face
- `maturity_periods`: prazo até o vencimento, em períodos
- `coupon_rate`: taxa de juros por período (fração do nominal)
"""
Base.@kwdef struct Asset
    name::String
    notional::Float64
    maturity_periods::Int
    coupon_rate::Float64 = 0.0
end

"""
    FundingSource

Fonte de captação do banco. O comportamento sob estresse é definido pelo
`stress_runoff_rate` (fração que evapora a cada período até o vencimento)
e pelo spread sB que o banco paga sobre o risk-free.

# Campos
- `name`: identificação
- `notional`: valor captado em t=0
- `maturity_periods`: prazo contratual
- `coupon_rate`: taxa risk-free + spread sB (taxa total paga por período)
- `stress_runoff_rate`: fração do nominal que sai por período sob estresse
- `is_stable`: se true, classifica como funding estável (NMD com baixo runoff, capital)
"""
Base.@kwdef struct FundingSource
    name::String
    notional::Float64
    maturity_periods::Int
    coupon_rate::Float64 = 0.0
    stress_runoff_rate::Float64 = 0.0
    is_stable::Bool = false
end

"""
    BankSnapshot

Fotografia do balanço bancário em t=0 com horizonte de projeção. Contém
caixa inicial, vetor de ativos, vetor de fontes de captação, taxa
risk-free por período e horizonte de análise.

# Campos
- `name`: identificação
- `cash_initial`: caixa em t=0 (inclui buffer pré-posicionado)
- `assets`: vetor de Asset
- `funding_sources`: vetor de FundingSource
- `risk_free_rate`: r_f por período
- `horizon`: número de períodos para projetar
"""
Base.@kwdef struct BankSnapshot
    name::String
    cash_initial::Float64
    assets::Vector{Asset}
    funding_sources::Vector{FundingSource}
    risk_free_rate::Float64 = 0.0
    horizon::Int = 12
end

"""
    asset_cashflow_at(asset, period)

Fluxo contratual de entrada gerado pelo ativo no período `period` (juros
acumulado entre t-1 e t, mais o principal se for a data de vencimento).
Retorna 0 se o ativo já expirou.
"""
function asset_cashflow_at(asset::Asset, period::Int)
    if period > asset.maturity_periods || period < 1
        return 0.0
    end
    interest = asset.notional * asset.coupon_rate
    if period == asset.maturity_periods
        return interest + asset.notional
    end
    return interest
end

"""
    funding_outflow_at(source, period)

Fluxo de saída devido à fonte de captação no período `period`. Considera
o runoff stressado (fração que evapora por período) e a devolução do
principal residual no vencimento.
"""
function funding_outflow_at(source::FundingSource, period::Int)
    if period > source.maturity_periods || period < 1
        return 0.0
    end
    if period == source.maturity_periods
        # No vencimento, devolve o principal residual após runoff
        consumed = source.stress_runoff_rate * (source.maturity_periods - 1)
        consumed = min(consumed, 1.0)
        residual_principal = source.notional * (1 - consumed)
        interest = source.notional * (1 - consumed) * source.coupon_rate
        return residual_principal + interest
    end
    # Período intermediário: runoff + juros sobre o saldo
    consumed_before = source.stress_runoff_rate * (period - 1)
    consumed_before = min(consumed_before, 1.0)
    runoff_amount = source.notional * source.stress_runoff_rate
    interest = source.notional * (1 - consumed_before) * source.coupon_rate
    return runoff_amount + interest
end
