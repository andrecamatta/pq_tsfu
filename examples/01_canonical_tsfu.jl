# Exemplo 1 — TSFu de um banco canônico
#
# Constroi a Term Structure of Available Funding para um banco estilizado
# e identifica o horizonte mais limitante (binding date) onde o saldo
# disponível atinge mínimo.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using PQTSFu

bank = canonical_bank(horizon = 6)
summary_tsfu(bank)
