# pq_tsfu

Pacote Julia que implementa a Term Structure of Available Funding (TSFu)
e a Term Structure of Forward Cumulated Funding (TSFCFu) com base em
Castagna e Fede (2013, *Measuring and Managing Liquidity Risk*), com
aplicação ao Funds Transfer Pricing por maturidade.

Código de apoio ao artigo "Term structure of available funding e forward
cumulated funding" da publicação Pílulas de Quant.

**Demo interativa:** <https://andrecamatta.github.io/pq_tsfu/> — editor de
ativos e fontes de captação com gráficos de TSFu e TSFCFu em tempo real.

## Escopo

Modela uma fotografia bancária com ativos e fontes de captação de prazos
e perfis comportamentais distintos, e calcula:

- TSFu(t₀, t) para todo t no horizonte: vetor AVL(t₀, t) sob cenário de
  estresse, conforme equação 7.2 de Castagna e Fede.
- Horizonte mais limitante (binding date) em que o buffer pré-posicionado
  precisa ter sido construído com tamanho suficiente.
- TSFCFu: cumulado forward em cada vencimento T_i, monotonicamente
  não-crescente em maturidade (eq. 7.16 de Castagna e Fede).
- Curva de FTP por maturidade pelo método Matched-Maturity Marginal.
- Preço interno de novo empréstimo de prazo arbitrário, com
  decomposição em risk-free, funding spread, liquidity premium e
  capital charge.

O pacote é didático. Não substitui sistemas de produção de tesouraria
(Oracle FTP, SAS ALM, Wolters Kluwer OneSumX, FIS Ambit Liquidity).

## Instalação

```julia
] activate .
] instantiate
```

## Uso mínimo

```julia
using PQTSFu

# Banco canônico do exemplo
bank = canonical_bank(horizon = 6)
summary_tsfu(bank)

# Banco brasileiro estilizado de S1
bank_br = brazilian_bank(horizon = 6)
curve = matched_maturity_ftp_curve(bank_br)

# Pricing de empréstimo de 5 anos
result = price_new_loan(bank_br, 50.0, 5; capital_charge = 0.005)
```

## Exemplos

- `examples/01_canonical_tsfu.jl`: TSFu de banco canônico com identificação de horizonte mais limitante.
- `examples/02_tsfcfu_cumulative.jl`: TSFCFu como cumulado forward não-crescente em maturidade.
- `examples/03_loan_pricing_5y.jl`: precificação de empréstimo de 5 anos via FTP por maturidade.

Executar:

```bash
julia examples/01_canonical_tsfu.jl
```

## Testes

```julia
] test
```

7 testsets cobrindo: construção de tipos, fluxo de caixa de ativo, TSFu sob
estresse pesado, TSFu de banco canônico, consistência do roll-forward, TSFcF
diagonal coincidente com TSFu, FTP crescente em prazo, pricing de empréstimo.

## Estrutura

```
src/
  PQTSFu.jl     # módulo principal
  types.jl      # Asset, FundingSource, BankSnapshot
  tsfu.jl       # project_avl, compute_tsfu, compute_tsfcfu, binding_horizon
  ftp.jl        # funding_curve_at, matched_maturity_ftp_curve, price_new_loan, balanced_bank
examples/
  01_canonical_tsfu.jl
  02_tsfcf_rolling.jl
  03_loan_pricing_5y.jl
test/
  runtests.jl
```

## Referências

- CASTAGNA, A.; FEDE, F. *Measuring and Managing Liquidity Risk*. Wiley Finance, 2013.
- GRANT, J. *Liquidity Transfer Pricing: A Guide to Better Practice*. BIS FSI Paper 10, 2011.
- CADAMAGNANI, F.; HARIMOHAN, R.; TANGRI, K. A bank within a bank. *BoE Quarterly Bulletin*, 2015.
- BCBS. *Basel III: The Net Stable Funding Ratio* (BCBS 295), 2014.

## Licença

MIT.
