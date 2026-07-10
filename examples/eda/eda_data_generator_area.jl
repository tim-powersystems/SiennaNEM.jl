using PowerSystems

const PSY = PowerSystems


gen_to_bus = SiennaNEM.get_map_from_df(data["generator"], :id_gen, :id_bus)
bus_to_area = SiennaNEM.get_map_from_df(data["bus"], :id_bus, :id_area)
bus_to_name = SiennaNEM.get_map_from_df(data["bus"], :id_bus, :name)

gen_to_area = Dict(
    id_gen => bus_to_area[id_bus]
    for (id_gen, id_bus) in gen_to_bus
)

data["generator"].id_area = [
    gen_to_area[id_gen]
    for id_gen in data["generator"].id_gen
]

bus_to_gen = Dict{Int64, Vector{Int64}}()
for (gen, bus) in gen_to_bus
    if !haskey(bus_to_gen, bus)
        bus_to_gen[bus] = Int64[]
    end
    push!(bus_to_gen[bus], gen)
end
area_to_gen = Dict{Int64, Vector{Int64}}()
for (gen, area) in gen_to_area
    if !haskey(area_to_gen, area)
        area_to_gen[area] = Int64[]
    end
    push!(area_to_gen[area], gen)
end

using DataFrames

# Get unique DataTypes available in each area
area_to_datatypes = Dict{Int64, Vector{DataType}}()
for row in eachrow(data["generator"])
    id_area = row.id_area
    datatype = row.DataType
    
    if !haskey(area_to_datatypes, id_area)
        area_to_datatypes[id_area] = DataType[]
    end
    
    if datatype ∉ area_to_datatypes[id_area]
        push!(area_to_datatypes[id_area], datatype)
    end
end

# Get unique DataTypes available in each bus
bus_to_datatypes = Dict{Int64, Vector{DataType}}()
for row in eachrow(data["generator"])
    id_bus = row.id_bus
    datatype = row.DataType
    
    if !haskey(bus_to_datatypes, id_bus)
        bus_to_datatypes[id_bus] = DataType[]
    end
    
    if datatype ∉ bus_to_datatypes[id_bus]
        push!(bus_to_datatypes[id_bus], datatype)
    end
end

# Create summary DataFrames
df_area_types = DataFrame(
    id_area = Int64[],
    area_name = String[],
    DataType = DataType[],
    count = Int64[]
)

for id_area in sort(collect(keys(area_to_datatypes)))
    area_name = get(area_to_name, id_area, "Area $id_area")
    for dt in sort(area_to_datatypes[id_area], by=string)
        count = sum((data["generator"].id_area .== id_area) .& (data["generator"].DataType .== dt))
        push!(df_area_types, (id_area=id_area, area_name=area_name, DataType=dt, count=count))
    end
end

df_bus_types = DataFrame(
    id_bus = Int64[],
    bus_name = String[],
    DataType = DataType[],
    count = Int64[]
)

for id_bus in sort(collect(keys(bus_to_datatypes)))
    bus_name = get(bus_to_name, id_bus, "Bus $id_bus")
    for dt in sort(bus_to_datatypes[id_bus], by=string)
        count = sum((data["generator"].id_bus .== id_bus) .& (data["generator"].DataType .== dt))
        push!(df_bus_types, (id_bus=id_bus, bus_name=bus_name, DataType=dt, count=count))
    end
end

# Display summaries
show(df_area_types, allrows=true, allcols=true)
show(df_bus_types, allrows=true, allcols=true)

# 20×4 DataFrame
#  Row │ id_area  area_name  DataType              count 
#      │ Int64    String     DataType              Int64 
# ─────┼─────────────────────────────────────────────────
#    1 │       1  QLD        HydroDispatch             2
#    2 │       1  QLD        RenewableDispatch         6
#    3 │       1  QLD        RenewableNonDispatch      4
#    4 │       1  QLD        ThermalStandard          20
#    5 │       2  NSW        HydroEnergyReservoir      4
#    6 │       2  NSW        RenewableDispatch         7
#    7 │       2  NSW        RenewableNonDispatch      4
#    8 │       2  NSW        ThermalStandard          10
#    9 │       3  VIC        HydroDispatch             1
#   10 │       3  VIC        HydroEnergyReservoir      6
#   11 │       3  VIC        RenewableDispatch         2
#   12 │       3  VIC        RenewableNonDispatch      1
#   13 │       3  VIC        ThermalStandard          11
#   14 │       4  TAS        HydroEnergyReservoir     17
#   15 │       4  TAS        RenewableDispatch         2
#   16 │       4  TAS        RenewableNonDispatch      1
#   17 │       4  TAS        ThermalStandard           3
#   18 │       5  SA         RenewableDispatch         4
#   19 │       5  SA         RenewableNonDispatch      2
#   20 │       5  SA         ThermalStandard          17

# 39×4 DataFrame
#  Row │ id_bus  bus_name  DataType              count 
#      │ Int64   String    DataType              Int64 
# ─────┼───────────────────────────────────────────────
#    1 │      1  NQ        HydroDispatch             2
#    2 │      1  NQ        RenewableDispatch         2
#    3 │      1  NQ        RenewableNonDispatch      1
#    4 │      1  NQ        ThermalStandard           2
#    5 │      2  CQ        RenewableDispatch         2
#    6 │      2  CQ        RenewableNonDispatch      1
#    7 │      2  CQ        ThermalStandard           4
#    8 │      3  GG        RenewableNonDispatch      1
#    9 │      3  GG        ThermalStandard           2
#   10 │      4  SQ        RenewableDispatch         2
#   11 │      4  SQ        RenewableNonDispatch      1
#   12 │      4  SQ        ThermalStandard          12
#   13 │      5  NNSW      RenewableDispatch         2
#   14 │      5  NNSW      RenewableNonDispatch      1
#   15 │      6  CNSW      RenewableDispatch         2
#   16 │      6  CNSW      RenewableNonDispatch      1
#   17 │      6  CNSW      ThermalStandard           2
#   18 │      7  SNW       RenewableDispatch         1
#   19 │      7  SNW       RenewableNonDispatch      1
#   20 │      7  SNW       ThermalStandard           7
#   21 │      8  SNSW      HydroEnergyReservoir      4
#   22 │      8  SNSW      RenewableDispatch         2
#   23 │      8  SNSW      RenewableNonDispatch      1
#   24 │      8  SNSW      ThermalStandard           1
#   25 │      9  VIC       HydroDispatch             1
#   26 │      9  VIC       HydroEnergyReservoir      6
#   27 │      9  VIC       RenewableDispatch         2
#   28 │      9  VIC       RenewableNonDispatch      1
#   29 │      9  VIC       ThermalStandard          11
#   30 │     10  TAS       HydroEnergyReservoir     17
#   31 │     10  TAS       RenewableDispatch         2
#   32 │     10  TAS       RenewableNonDispatch      1
#   33 │     10  TAS       ThermalStandard           3
#   34 │     11  CSA       RenewableDispatch         2
#   35 │     11  CSA       RenewableNonDispatch      1
#   36 │     11  CSA       ThermalStandard          15
#   37 │     12  SESA      RenewableDispatch         2
#   38 │     12  SESA      RenewableNonDispatch      1
#   39 │     12  SESA      ThermalStandard           2

# NOTE:
# 1. Bus 5 only has Renewable generators

# Find generator with biggest pmax in each area
df_max_gen_by_area = DataFrame(
    id_area = Int64[],
    area_name = String[],
    id_gen = Int64[],
    name = String[],
    tech = String[],
    DataType = DataType[],
    n = Int64[],
    pmax = Float64[]
)

for id_area in sort(unique(data["generator"].id_area))
    # Filter generators in this area
    area_gens = data["generator"][data["generator"].id_area .== id_area, :]
    
    # Find generator with maximum pmax
    max_idx = argmax(area_gens.pmax)
    max_gen = area_gens[max_idx, :]
    
    area_name = get(area_to_name, id_area, "Area $id_area")
    
    push!(df_max_gen_by_area, (
        id_area = id_area,
        area_name = area_name,
        id_gen = max_gen.id_gen,
        name = max_gen.name,
        tech = max_gen.tech,
        DataType = max_gen.DataType,
        n = max_gen.n,
        pmax = max_gen.pmax
    ))
end

println("\n" * "="^80)
println("Generator with Largest Pmax in Each Area")
println("="^80)
show(df_max_gen_by_area, allrows=true, allcols=true)
println()

# Find ThermalStandard generator with biggest pmax in each area
df_max_thermal_by_area = DataFrame(
    id_area = Int64[],
    area_name = String[],
    id_gen = Int64[],
    name = String[],
    tech = String[],
    DataType = DataType[],
    n = Int64[],
    pmax = Float64[]
)

for id_area in sort(unique(data["generator"].id_area))
    # Filter ThermalStandard generators in this area
    area_thermal_gens = data["generator"][
        (data["generator"].id_area .== id_area) .& 
        (data["generator"].DataType .== PSY.ThermalStandard), 
        :
    ]
    
    # Skip if no thermal generators in this area
    if nrow(area_thermal_gens) == 0
        continue
    end
    
    # Find generator with maximum pmax
    max_idx = argmax(area_thermal_gens.pmax)
    max_gen = area_thermal_gens[max_idx, :]
    
    area_name = get(area_to_name, id_area, "Area $id_area")
    
    push!(df_max_thermal_by_area, (
        id_area = id_area,
        area_name = area_name,
        id_gen = max_gen.id_gen,
        name = max_gen.name,
        tech = max_gen.tech,
        DataType = max_gen.DataType,
        n = max_gen.n,
        pmax = max_gen.pmax
    ))
end

println("\n" * "="^80)
println("ThermalStandard Generator with Largest Pmax in Each Area")
println("="^80)
show(df_max_thermal_by_area, allrows=true, allcols=true)
println()
