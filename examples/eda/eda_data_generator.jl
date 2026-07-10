using DataFrames

cols = [:tech, :type, :DataType, :PrimeMovers, :ThermalFuels]
df = combine(groupby(data["generator"], cols), nrow => :count)
sort!(df, [:ThermalFuels, :PrimeMovers, :tech, :count])
#  Row │ tech                         type                         DataType              PrimeMovers           ThermalFuels                       count 
#      │ String31                     String31                     DataType              PrimeMovers           ThermalFuels?                      Int64 
# ─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │ Black Coal NSW               Steam Sub Critical           ThermalStandard       PrimeMovers.ST = 20   ThermalFuels.COAL = 1                  4
#    2 │ Black Coal QLD               Steam Sub Critical           ThermalStandard       PrimeMovers.ST = 20   ThermalFuels.COAL = 1                  4
#    3 │ Black Coal QLD               Steam Super Critical         ThermalStandard       PrimeMovers.ST = 20   ThermalFuels.COAL = 1                  4
#    4 │ Brown Coal                   Steam Sub Critical           ThermalStandard       PrimeMovers.ST = 20   ThermalFuels.COAL = 1                  1
#    5 │ Brown Coal VIC               Steam Sub Critical           ThermalStandard       PrimeMovers.ST = 20   ThermalFuels.COAL = 1                  2
#    6 │ Diesel                       Reciprocating Engine         ThermalStandard       PrimeMovers.IC = 17   ThermalFuels.DISTILLATE_FUEL_OIL…      7
#    7 │ CCGT                         CCGT                         ThermalStandard       PrimeMovers.CC = 4    ThermalFuels.NATURAL_GAS = 7           9
#    8 │ OCGT                         Frame 6B                     ThermalStandard       PrimeMovers.GT = 12   ThermalFuels.NATURAL_GAS = 7           1
#    9 │ OCGT                         GE Frame 5                   ThermalStandard       PrimeMovers.GT = 12   ThermalFuels.NATURAL_GAS = 7           1
#   10 │ OCGT                         Gas-powered steam turbine    ThermalStandard       PrimeMovers.GT = 12   ThermalFuels.NATURAL_GAS = 7           2
#   11 │ OCGT                         OCGT                         ThermalStandard       PrimeMovers.GT = 12   ThermalFuels.NATURAL_GAS = 7          24
#   12 │ Hydrogen-based gas turbines  Hydrogen-based gas turbines  ThermalStandard       PrimeMovers.GT = 12   ThermalFuels.OTHER = 14                2
#   13 │ Reservoir                    Nozzle-spear Pelton          HydroEnergyReservoir  PrimeMovers.HY = 16   missing                                1
#   14 │ Reservoir                    Kaplan                       HydroEnergyReservoir  PrimeMovers.HY = 16   missing                                2
#   15 │ Reservoir                    Pelton                       HydroEnergyReservoir  PrimeMovers.HY = 16   missing                                2
#   16 │ Reservoir                    Francis                      HydroEnergyReservoir  PrimeMovers.HY = 16   missing                               22
#   17 │ Run-of-River                 Francis / Pelton             HydroDispatch         PrimeMovers.HY = 16   missing                                1
#   18 │ Run-of-River                 Pelton                       HydroDispatch         PrimeMovers.HY = 16   missing                                1
#   19 │ Run-of-River                 Vertical Francis             HydroDispatch         PrimeMovers.HY = 16   missing                                1
#   20 │ LargePV                      LargePV                      RenewableDispatch     PrimeMovers.PVe = 21  missing                               10
#   21 │ RoofPV                       RoofPV                       RenewableNonDispatch  PrimeMovers.PVe = 21  missing                               12
#   22 │ Wind                         Wind                         RenewableDispatch     PrimeMovers.WT = 22   missing                               10

# # NOTE: for data pure from PISP:
# cols = [:tech, :type]
# df = combine(groupby(data["generator"], cols), nrow => :count)
# sort!(df, [:tech, :type, :count])

unique(data["generator"][data["generator"].n .> 1, :DataType])
# 3-element Vector{DataType}:
#  ThermalStandard
#  HydroDispatch
#  HydroEnergyReservoir

# get generator with fuel that is not "Solar" or "Wind"
ids_gen_nvre = findall(x -> x ∉ ["Solar", "Wind"], data["generator"].fuel)
data["generator_pmax_tsf"][!, string.(ids_gen_nvre)]
