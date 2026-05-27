"""
    project_avl(bank, t)

Calcula AVL(t₀, t) — o caixa disponível em t sob cenário de estresse,
visto a partir de t₀=0. Soma o caixa inicial mais entradas contratuais
de ativos e subtrai saídas estressadas de captação até t.

Boundary conditions de Castagna e Fede (2013, §7.6):
- AVL(t₀, t) ≥ 0 para todo t no horizonte (banco sobrevive)
- AVL(t₀, tᵦ) = 0 no horizonte ideal (buffer right-sized)
"""
function project_avl(bank::BankSnapshot, t::Int)
    if t < 0
        return bank.cash_initial
    end
    cash = bank.cash_initial
    for k in 1:t
        for asset in bank.assets
            cash += asset_cashflow_at(asset, k)
        end
        for source in bank.funding_sources
            cash -= funding_outflow_at(source, k)
        end
    end
    return cash
end

"""
    compute_tsfu(bank)

Term Structure of Available Funding completa: vetor [AVL(t₀, 0),
AVL(t₀, 1), …, AVL(t₀, T)] indexado pelos períodos do horizonte.

Implementa a equação 7.2 de Castagna e Fede (2013).
"""
function compute_tsfu(bank::BankSnapshot)
    return [project_avl(bank, t) for t in 0:bank.horizon]
end

"""
    binding_horizon(bank)

Identifica o período mais limitante (em que AVL atinge mínimo). Em
estresse, é a data em que o buffer pré-posicionado precisa ter sido
construído com tamanho suficiente para cobrir o gap.

Retorna NamedTuple com `period` e `min_avl`.
"""
function binding_horizon(bank::BankSnapshot)
    tsfu = compute_tsfu(bank)
    min_idx = argmin(tsfu)
    return (period = min_idx - 1, min_avl = tsfu[min_idx])
end

"""
    roll_forward(bank, f)

Avança a fotografia do banco para o período t_f, materializando as
entradas e saídas realizadas até t_f e devolvendo um novo BankSnapshot
com cash_initial atualizado e horizonte reduzido. Os ativos e fontes de
captação que ainda não venceram permanecem no novo snapshot, com
maturidades reduzidas em f.
"""
function roll_forward(bank::BankSnapshot, f::Int)
    new_cash = project_avl(bank, f)
    new_assets = Asset[]
    for a in bank.assets
        if a.maturity_periods > f
            push!(new_assets, Asset(
                name = a.name,
                notional = a.notional,
                maturity_periods = a.maturity_periods - f,
                coupon_rate = a.coupon_rate,
            ))
        end
    end
    new_sources = FundingSource[]
    for s in bank.funding_sources
        if s.maturity_periods > f
            consumed = s.stress_runoff_rate * f
            consumed = min(consumed, 1.0)
            push!(new_sources, FundingSource(
                name = s.name,
                notional = s.notional * (1 - consumed),
                maturity_periods = s.maturity_periods - f,
                coupon_rate = s.coupon_rate,
                stress_runoff_rate = s.stress_runoff_rate,
                is_stable = s.is_stable,
            ))
        end
    end
    return BankSnapshot(
        name = bank.name * " @ t=$f",
        cash_initial = new_cash,
        assets = new_assets,
        funding_sources = new_sources,
        risk_free_rate = bank.risk_free_rate,
        horizon = bank.horizon - f,
    )
end

"""
    compute_tsfcf(bank)

Term Structure of Forward Cumulated Funding: matriz de TSFu projetadas a
partir de cada reavaliação futura t_f. A célula [f+1, k] contém
AVL(t_f, t_{f+k}).

Visão dinâmica que complementa a TSFu estática, conforme §7.6.1.
"""
function compute_tsfcf(bank::BankSnapshot)
    H = bank.horizon
    # Inicializa com NaN para células fora do triangulo válido
    surface = fill(NaN, H + 1, H + 1)
    for f in 0:H
        bank_at_f = (f == 0) ? bank : roll_forward(bank, f)
        for k in 0:(H - f)
            surface[f + 1, k + 1] = project_avl(bank_at_f, k)
        end
    end
    return surface
end

"""
    summary_tsfu(bank)

Imprime relatório formatado da TSFu e do horizonte de breach.
"""
function summary_tsfu(bank::BankSnapshot)
    println("="^72)
    println("Term Structure of Available Funding — $(bank.name)")
    println("="^72)
    @printf "Caixa inicial: %.2f\n" bank.cash_initial
    @printf "Ativos: %d, fontes de captação: %d\n" length(bank.assets) length(bank.funding_sources)
    @printf "Horizonte: %d períodos\n\n" bank.horizon

    tsfu = compute_tsfu(bank)
    println("TSFu(t₀, t):")
    for (t, avl) in enumerate(tsfu)
        period = t - 1
        marker = avl < 0 ? " ← BREACH" : (avl < 0.01 * abs(maximum(tsfu)) ? " ← binding" : "")
        @printf "  t = %2d → AVL = %10.2f%s\n" period avl marker
    end

    bh = binding_horizon(bank)
    println("\nHorizonte mais limitante: t = $(bh.period), AVL mínimo = $(round(bh.min_avl, digits=2))")
    if bh.min_avl < 0
        println("⚠ Buffer insuficiente: AVL fica negativo. LB precisa de incremento de $(round(-bh.min_avl, digits=2)).")
    end
    println("="^72)
    return tsfu
end
