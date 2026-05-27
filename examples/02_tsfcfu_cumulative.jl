# Exemplo 2 — Term Structure of Forward Cumulated Funding (TSFCFu)
#
# Para cada vencimento T_i no horizonte, a TSFCFu agrega a liquidez
# disponível para investimento ilíquido em T_i e em todas as maturidades
# posteriores até T_b. Curva monotonicamente não-crescente em maturidade.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQTSFu
using Printf

bank = balanced_bank(horizon = 6)
tsfu = compute_tsfu(bank)
tsfcfu = compute_tsfcfu(bank)

println("="^72)
println("TSFCFu de $(bank.name)")
println("="^72)
@printf "%-8s %12s %12s\n" "T_i" "AVL(t0,T_i)" "TSFCFu(T_i)"
println("-"^(8 + 12*2 + 2))

for i in 0:bank.horizon
    @printf "%-8d %12.2f %12.2f\n" i tsfu[i+1] tsfcfu[i+1]
end

println()
println("Leitura: a TSFCFu agrega o AVL não-negativo de T_i até T_b.")
println("É o teto de comprometimento em ativos ilíquidos maturando em T_i ou depois.")
println("Em T_b, TSFCFu coincide com max(0, AVL(t0, T_b)).")
