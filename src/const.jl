# TODO:
#   Check and support all types below
# 
# unique(data["generator"][:, [:tech, :type]])
# combine(groupby(data["generator"], [:tech, :type]), nrow => :count)
# 
# Row │ tech                         type                         count 
#     │ String31                     String31                     Int64 
# ───-┼─────────────────────────────────────────────────────────────────
#   1 │ Black Coal NSW               Steam Sub Critical               4
#   2 │ Black Coal QLD               Steam Sub Critical               4
#   3 │ Black Coal QLD               Steam Super Critical             4
#   4 │ Brown Coal VIC               Steam Sub Critical               2
#   5 │ Brown Coal                   Steam Sub Critical               1
#   6 │ Diesel                       Reciprocating Engine             7
#   7 │ Run-of-River                 Vertical Francis                 1
#   8 │ Run-of-River                 Francis / Pelton                 1
#   9 │ Run-of-River                 Pelton                           1
#  10 │ Reservoir                    Francis                         22
#  11 │ Reservoir                    Pelton                           2
#  12 │ Reservoir                    Kaplan                           2
#  13 │ Reservoir                    Nozzle-spear Pelton              1
#  14 │ Hydrogen-based gas turbines  Hydrogen-based gas turbines      2
#  15 │ OCGT                         OCGT                            24
#  16 │ OCGT                         GE Frame 5                       1
#  17 │ OCGT                         Gas-powered steam turbine        2
#  18 │ OCGT                         Frame 6B                         1
#  19 │ CCGT                         CCGT                             9
#  20 │ RoofPV                       RoofPV                          12
#  21 │ LargePV                      LargePV                         10
#  22 │ Wind                         Wind                            10

# NOTE:
#   Sienna also has WS for off shore wind turbine, but no off shore wind in
# Australia for now
#   Various other coal and oil fuel availables.

# https://nrel-sienna.github.io/PowerSystems.jl/stable/api/enumerated_types/

# Define once (const binding), then repopulate by mutation for Revise friendliness.
const tech_to_primemover = Dict{String,PrimeMovers}()
const tech_to_datatype = Dict{String,Any}()
const tech_to_fuel = Dict{String,ThermalFuels}()
const area_to_name = OrderedDict{Int,String}()
const area_to_tref_peak_demand = OrderedDict{Int,Float64}()
const area_to_tref_summer = OrderedDict{Int,Float64}()
const area_to_tref_winter = OrderedDict{Int,Float64}()
const line_to_rvcap_peak_demand = OrderedDict{Int,Float64}()
const line_to_fwcap_peak_demand = OrderedDict{Int,Float64}()
const line_to_rvcap_summer = OrderedDict{Int,Float64}()
const line_to_fwcap_summer = OrderedDict{Int,Float64}()
const line_to_tech = OrderedDict{Int,String}()
const forward_thermal_notconstrained = Vector{Int}()
const reverse_thermal_notconstrained = Vector{Int}()
const optimization_result_handlers = Vector{Tuple{String,Function}}()
const constant_temperature = Dict{String,Float64}()

function _populate_constants!()
    merge!(empty!(tech_to_primemover), Dict(
        "Black Coal NSW" => PrimeMovers.ST,
        "Black Coal QLD" => PrimeMovers.ST,
        "Brown Coal VIC" => PrimeMovers.ST,
        "Brown Coal" => PrimeMovers.ST,
        "Diesel" => PrimeMovers.IC,
        "Run-of-River" => PrimeMovers.HY,
        "Reservoir" => PrimeMovers.HY,
        "Hydrogen-based gas turbines" => PrimeMovers.GT,
        "OCGT" => PrimeMovers.GT,
        "CCGT" => PrimeMovers.CC,
        "RoofPV" => PrimeMovers.PVe,
        "LargePV" => PrimeMovers.PVe,
        "Wind" => PrimeMovers.WT,
        "BESS" => PrimeMovers.BA,
        "PS" => PrimeMovers.HY,
    ))
    # TODO: use tech instead of type
    merge!(empty!(tech_to_datatype), Dict(
        "Black Coal NSW" => ThermalStandard,
        "Black Coal QLD" => ThermalStandard,
        "Brown Coal VIC" => ThermalStandard,
        "Brown Coal" => ThermalStandard,
        "Diesel" => ThermalStandard,
        "Run-of-River" => HydroDispatch,
        "Reservoir" => HydroTurbine,
        "Hydrogen-based gas turbines" => ThermalStandard,
        "OCGT" => ThermalStandard,
        "CCGT" => ThermalStandard,
        "RoofPV" => RenewableNonDispatch,
        "LargePV" => RenewableDispatch,
        "Wind" => RenewableDispatch,
        "BESS" => EnergyReservoirStorage,
        "PS" => HydroPumpTurbine,
    ))
    merge!(empty!(tech_to_fuel), Dict(
        "Black Coal NSW" => ThermalFuels.COAL,
        "Black Coal QLD" => ThermalFuels.COAL,
        "Brown Coal VIC" => ThermalFuels.COAL,
        "Brown Coal" => ThermalFuels.COAL,
        "Diesel" => ThermalFuels.DISTILLATE_FUEL_OIL,
        "Hydrogen-based gas turbines" => ThermalFuels.OTHER,
        "OCGT" => ThermalFuels.NATURAL_GAS,
        "CCGT" => ThermalFuels.NATURAL_GAS,
    ))
    merge!(empty!(area_to_name), OrderedDict(
        1 => "QLD",
        2 => "NSW",
        3 => "VIC",
        4 => "TAS",
        5 => "SA",
    ))
    # TODO: request this data to be available in PISP
    merge!(empty!(area_to_tref_peak_demand), OrderedDict(
        1 => 37.0,
        2 => 42.0,
        3 => 41.0,
        4 => 7.7,
        5 => 43.0,
    ))
    merge!(empty!(area_to_tref_summer), OrderedDict(
        1 => 32.0,
        2 => 32.0,
        3 => 32.0,
        4 => 7.7,
        5 => 35.0,
    ))
    merge!(empty!(area_to_tref_winter), OrderedDict(
        1 => 15.0,
        2 => 9.0,
        3 => 8.0,
        4 => 1.2,
        5 => 11.0,
    ))
    merge!(empty!(line_to_rvcap_summer), OrderedDict(
        1 => 1200.0,
        2 => 750.0,
        3 => 2100.0,
        4 => 1165.0,
        5 => 150.0,
        6 => 930.0,
        7 => 4490.0,
        8 => 2540.0,
        9 => 2320.0,
        10 => 400.0,
        11 => 650.0,
        12 => 650.0,
        13 => 200.0,
        14 => 478.0,
    ))
    merge!(empty!(line_to_fwcap_summer), OrderedDict(
        1 => 1200.0,
        2 => 700.0,
        3 => 1100.0,
        4 => 745.0,
        5 => 50.0,
        6 => 910.0,
        7 => 4490.0,
        8 => 2540.0,
        9 => 2700.0,
        10 => 1000.0,
        11 => 650.0,
        12 => 650.0,
        13 => 220.0,
        14 => 594.0,
    ))
    merge!(empty!(line_to_rvcap_peak_demand), OrderedDict(
        1 => 1200.0,
        2 => 750.0,
        3 => 2100.0,
        4 => 1205.0,
        5 => 130.0,
        6 => 930.0,
        7 => 4490.0,
        8 => 2540.0,
        9 => 2320.0,
        10 => 400.0,
        11 => 650.0,
        12 => 650.0,
        13 => 100.0,
        14 => 478.0,
    ))
    merge!(empty!(line_to_fwcap_peak_demand), OrderedDict(
        1 => 1200.0,
        2 => 700.0,
        3 => 1100.0,
        4 => 685.0,
        5 => 0.0,
        6 => 910.0,
        7 => 4490.0,
        8 => 2540.0,
        9 => 2700.0,
        10 => 870.0,
        11 => 650.0,
        12 => 650.0,
        13 => 220.0,
        14 => 594.0,
    ))
    # TODO: find all future dc lines
    merge!(empty!(line_to_tech), OrderedDict(
        5 => "dc_ug",  # "Terranora", dc under ground cable 
        14 => "dc_ss",  # "Basslink", dc sub sea cable
        13 => "dc_ug",  # "Murraylink", dc under ground cable
        50 => "dc_ss",  # "TAS-VIC Option 1", "NL_109_INV35", dc sub sea cable
        51 => "dc_ss",  # "TAS-VIC Option 2", "NL_109_INV35", dc sub sea cable
    ))
    merge!(empty!(constant_temperature), Dict(
        "ac_oh_tref" => 20.0,  # °C, no reduction below this
        "ac_oh_tm" => 90.0,  # °C, maximum allowable line temperature
        "dc_ug_tref" => 38.0,  # °C, no reduction below this
        "dc_ug_derating_rate" => 0.125,  # 12.5% reduction per °C above base
    ))
    # Lines where capacity is not thermally derated
    append!(empty!(forward_thermal_notconstrained),  [1, 4, 6, 10, 12, 14])
    append!(empty!(reverse_thermal_notconstrained),  [3, 10, 11, 12, 14])
    append!(empty!(optimization_result_handlers), [
        ("expressions", read_expressions),
        ("aux_variables", read_aux_variables),
        ("parameters", read_parameters),
        ("variables", read_variables),
        ("duals", read_duals),
        ("realized_expressions", read_realized_expressions),
        ("realized_aux_variables", read_realized_aux_variables),
        ("realized_parameters", read_realized_parameters),
        ("realized_variables", read_realized_variables),
        ("realized_duals", read_realized_duals),
    ])
    return nothing
end
