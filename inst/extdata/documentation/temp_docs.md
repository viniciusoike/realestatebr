# Temporary Dataset Documentation

## ⚠️ Important Notice

This documentation is **automatically generated** based on column names, data patterns, and contextual analysis. It requires **manual review and validation** by domain experts familiar with Brazilian real estate data.

Fields marked with `[NEEDS REVIEW]` require special attention and verification.

---

## Datasets Requiring Documentation Review

### 1. abecip_indicators

#### SBPE Table
- **sbpe_total**: [NEEDS REVIEW] Appears to be total SBPE financing volume (nominal BRL)
- **sbpe_acquisition**: [NEEDS REVIEW] SBPE financing for property acquisitions
- **sbpe_construction**: [NEEDS REVIEW] SBPE financing for new construction
- **rural_total**: [NEEDS REVIEW] Rural property financing total
- **rural_acquisition**: [NEEDS REVIEW] Rural property acquisitions
- **rural_construction**: [NEEDS REVIEW] Rural property construction

#### Units Table  
- **units_total**: Total number of units financed
- **units_construction**: Units financed for construction
- **units_acquisition**: Units financed through acquisition
- **currency_construction**: [NEEDS REVIEW] Value in millions BRL for construction
- **currency_acquisition**: [NEEDS REVIEW] Value in millions BRL for acquisition

#### CGI Table
- **contracts**: Number of home equity loan contracts
- **value**: Total value of home equity loans
- **average_value**: Average loan value
- **default_rate**: Default rate (percentage)
- **average_term**: Average loan term (months)

### 2. abrainc_indicators

#### Indicator Table
- **vgv**: [NEEDS REVIEW] Likely "Valor Geral de Vendas" (Total Sales Value)
- **launches**: Number of new unit launches
- **sales**: Number of units sold
- **supply**: [NEEDS REVIEW] Available inventory/supply
- **vso**: [NEEDS REVIEW] "Velocidade de Vendas" (Sales velocity/rate)
- **social_housing**: Units under MCMV/CVA programs

#### Radar Table
- **index**: Business conditions index (0-10 scale)
- **components**: [NEEDS REVIEW] Individual radar components

#### Leading Table
- **permits**: Building permits issued
- **area**: [NEEDS REVIEW] Total permitted area (m²)

### 3. bcb_realestate

Complex multi-dimensional structure with series_info column split into v1-v5:
- **v1**: Main category (accounting/application/indices/sources/units)
- **v2**: Subcategory or geographic level
- **v3**: [NEEDS REVIEW] Additional classification
- **v4**: [NEEDS REVIEW] Time period or cohort
- **v5**: [NEEDS REVIEW] Additional detail level

### 4. secovi

- **vsm**: [NEEDS REVIEW] Likely "Valor por Metro Quadrado" (Value per square meter)
- **median_value**: Median property value
- **variation_month**: Monthly variation (%)
- **variation_year**: Annual variation (%)
- **sample_size**: [NEEDS REVIEW] Number of observations in sample

### 5. bis_rppi

#### Selected Series
- **real**: Real (inflation-adjusted) index
- **nominal**: Nominal price index
- **coverage**: [NEEDS REVIEW] Geographic coverage indicator

#### Detailed Series
- Multiple series codes requiring mapping to descriptions

### 6. rppi (FIPE)

- **index_nominal**: Nominal price index value
- **variation_month**: Monthly variation (%)
- **variation_year**: Annual variation (%)
- **variation_accumulated**: [NEEDS REVIEW] Accumulated variation period
- **sample_size**: Number of properties in sample

### 7. bcb_series

See bcb_metadata table for complete series descriptions. Common unclear abbreviations:
- **ICC**: [NEEDS REVIEW] Possibly "Índice de Confiança da Construção"
- **INCC**: National Construction Cost Index
- **IGP-M**: General Market Price Index
- **IPCA**: Broad Consumer Price Index

### 8. b3_stocks

- **ticker**: Stock ticker symbol
- **close**: Closing price
- **volume**: Trading volume
- **market_cap**: [NEEDS REVIEW] Market capitalization
- **dividend_yield**: [NEEDS REVIEW] Dividend yield percentage

### 9. fgv_indicators

- **incc**: National Construction Cost Index
- **incc_m**: [NEEDS REVIEW] INCC materials component
- **incc_mo**: [NEEDS REVIEW] INCC labor component
- **confidence**: [NEEDS REVIEW] Construction confidence index

### 10. cbic

#### Cement
- **production_1000t**: Production in thousands of tons
- **apparent_consumption**: [NEEDS REVIEW] Apparent consumption calculation method
- **per_capita_kg**: Per capita consumption in kilograms

#### Steel
- **avg_price**: Average price per unit
- **production**: Production volume
- **state variations**: Regional price/production differences

#### PIM
- **production_index**: Industrial production index (base: 2022 = 100)

---

## Translation Patterns Applied

### Standard Translations
- estado → state
- município → municipality  
- região → region
- ano → year
- mês → month
- trimestre → quarter
- data → date
- valor → value
- preço → price
- índice → index
- taxa → rate
- lançamentos → launches
- vendas → sales
- unidades → units
- financiamento → financing
- aluguel → rent

### Acronyms Preserved (Need Definition)
- SBPE: Sistema Brasileiro de Poupança e Empréstimo
- CGI: Crédito com Garantia de Imóvel
- VGV: Valor Geral de Vendas
- VSO: Velocidade de Vendas
- MCMV: Minha Casa Minha Vida
- CVA: Casa Verde Amarela
- INCC: Índice Nacional de Custo da Construção
- IGP-M: Índice Geral de Preços - Mercado
- IPCA: Índice de Preços ao Consumidor Amplo

---

## Review Checklist

For each dataset, please verify:

1. ✅ Column descriptions are accurate
2. ✅ Units of measurement are correct
3. ✅ Time periods and coverage are accurate
4. ✅ Geographic coverage is properly described
5. ✅ Acronyms are properly defined
6. ✅ Calculation methods are documented where relevant
7. ✅ Data sources and update frequencies are correct
8. ✅ Any data transformations or aggregations are noted

---

## Contributing

To improve this documentation:

1. Review fields marked `[NEEDS REVIEW]`
2. Add missing descriptions
3. Correct any inaccuracies
4. Provide context for Brazilian-specific terms
5. Document any known data quality issues
6. Add examples where helpful

Please submit updates via pull request or issue on GitHub.