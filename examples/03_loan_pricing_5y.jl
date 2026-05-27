# Exemplo 3 — Precificação de empréstimo de 5 anos via FTP por maturidade
#
# Aplica o método Matched-Maturity Marginal (Grant, 2011) sobre a TSFu
# vigente. Para cada candidato a novo empréstimo, calcula o FTP que a
# tesouraria deve cobrar da área de negócio.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQTSFu
using Printf

bank = brazilian_bank(horizon = 6)

println("="^72)
println("Curva de FTP por maturidade — $(bank.name)")
println("="^72)
println("Risk-free vigente: $(round(100 * bank.risk_free_rate, digits=2))% por período\n")

curve = matched_maturity_ftp_curve(bank)
@printf "%-12s %-15s %-15s\n" "Prazo (t)" "FTP total" "Spread sB"
println("-"^45)
for (t, rate) in curve
    spread = rate - bank.risk_free_rate
    @printf "%-12d %-15.4f %-15.4f\n" t rate spread
end

println("\n" * "="^72)
println("Pricing de empréstimos por prazo (notional = 50)")
println("="^72)

for prazo in [1, 2, 3, 5]
    result = price_new_loan(bank, 50.0, prazo; capital_charge = 0.005)
    println("\nEmpréstimo de $(prazo) ano(s):")
    @printf "  risk-free            : %.4f\n" result.risk_free
    @printf "  funding spread (sB)  : %.4f\n" result.funding_spread
    @printf "  liquidity premium    : %.6f\n" result.liquidity_premium
    @printf "  capital charge       : %.4f\n" result.capital_charge
    @printf "  ─────────────────────────────────\n"
    @printf "  FTP total            : %.4f (%.2f%%)\n" result.total_ftp 100*result.total_ftp
    @printf "  AVL deformation      : %.4f\n" result.avl_deformation
end

println("\nNote como o FTP cresce com o prazo, refletindo a curva de funding marginal.")
println("Empréstimos mais longos consomem buffer por mais tempo e absorvem mais spread.")
