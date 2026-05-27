"""
    project_avl(bank, t)

Calcula AVL(t₀, t) — o caixa disponível em t sob cenário de estresse,
visto a partir de t₀=0. Soma o caixa inicial mais entradas contratuais
de ativos e subtrai saídas estressadas de captação até t.

Boundary conditions de Castagna e Fede (2013):
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
    compute_tsfcfu(bank)

Term Structure of Forward Cumulated Funding (TSFCFu) conforme Castagna
e Fede.

Para cada vencimento Tᵢ no horizonte, agrega a liquidez disponível
para investimento ilíquido em Tᵢ e em todas as maturidades posteriores
até Tᵦ. Adaptação do modelo simplificado: soma das contribuições
não-negativas da TSFu de Tᵢ até Tᵦ.

A curva resultante é monotonicamente não-crescente em maturidade. O
primeiro elemento iguala o cumulado total da TSFu ao longo do horizonte;
o último elemento iguala o AVL terminal (se positivo).
"""
function compute_tsfcfu(bank::BankSnapshot)
    H = bank.horizon
    tsfu = compute_tsfu(bank)
    result = zeros(H + 1)
    s = 0.0
    # Soma sufixo: TSFCFu[i] = sum_{j=i}^{H} max(0, TSFu[j])
    for i in H:-1:0
        s += max(0.0, tsfu[i + 1])
        result[i + 1] = s
    end
    return result
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
