# Exemplo 2 — Term Structure of Forward Cumulated Funding (TSFcF)
#
# Diferença chave: TSFu mostra AVL(t₀, tᵢ) ancorado em t=0. TSFcF mostra
# AVL(t_f, t_{f+k}) — como a TSFu evolui se o banco rolar para t_f e
# refizer a projeção a partir desse ponto.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQTSFu
using Printf

bank = canonical_bank(horizon = 6)
tsfcf = compute_tsfcf(bank)

println("="^72)
println("TSFcF de $(bank.name)")
println("="^72)
println("\nMatriz [linha = origem t_f, coluna = horizonte k]:")
println("Cada célula é AVL(t_f, t_{f+k}).")
println()

@printf "%-6s" "t_f \\ k"
for k in 0:bank.horizon
    @printf "%10d" k
end
println()
println("-"^(7 + 10 * (bank.horizon + 1)))

for f in 0:bank.horizon
    @printf "%-6d|" f
    for k in 0:bank.horizon
        v = tsfcf[f + 1, k + 1]
        if isnan(v)
            @printf "%10s" "—"
        else
            @printf "%10.2f" v
        end
    end
    println()
end

println("\nLeitura: cada linha mostra a TSFu se o banco for reavaliado em t=f.")
println("A diagonal AVL(t, t) mostra o caixa disponível imediato em cada data.")
