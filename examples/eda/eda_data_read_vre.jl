using DataFrames
using CSV
using Statistics
using Dates

vre_dir = joinpath(@__DIR__, "../../", "data", "out-ref4006-poe10", "csv")
rez_mesh_file_name = "rez_mesh.csv"
rooftop_mesh_file_name = "rooftop_mesh.csv"
data["rez_mesh"] = CSV.read(joinpath(vre_dir, rez_mesh_file_name), DataFrame)
data["rooftop_mesh"] = CSV.read(joinpath(vre_dir, rooftop_mesh_file_name), DataFrame)

# add bus_name and id_area to rooftop_mesh as it is currently missing
bus_to_name = SiennaNEM.get_map_from_df(data["bus"], :id_bus, :name)
add_data_col_by_id!(data["rooftop_mesh"], bus_to_name; id_col=:id_bus, data_col=:bus_name)
SiennaNEM.add_id_area_col!(data["rez_mesh"], bus_to_area)
SiennaNEM.add_id_area_col!(data["rooftop_mesh"], bus_to_area)

# add tref_summer to rooftop_mesh and rez_mesh data for later use in solar derating factor calculation
add_data_col_by_id!(data["rez_mesh"], SiennaNEM.area_to_tref_summer; data_col=:tref_summer)
add_data_col_by_id!(data["rooftop_mesh"], SiennaNEM.area_to_tref_summer; data_col=:tref_summer)

temperature_dir = joinpath(@__DIR__, "../..", "data/weather/temperature")
rez_temperature_file_name = "REZ_mesh_2m_temperature-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"
rez_ta_df = CSV.read(joinpath(temperature_dir, rez_temperature_file_name), DataFrame)
rooftop_temperature_file_name = "Rooftop_mesh_2m_temperature-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"
rooftop_ta_df = CSV.read(joinpath(temperature_dir, rooftop_temperature_file_name), DataFrame)

count(ismissing, Matrix(rez_ta_df))
count(ismissing, Matrix(rooftop_ta_df))

# remove rooftop with missing temperature data
id_rooftop_mesh_with_missing =
    unique(rooftop_ta_df.id_rooftop_mesh[ismissing.(rooftop_ta_df.value)])
filter!(row -> !(row.id_rooftop_mesh in id_rooftop_mesh_with_missing), rooftop_ta_df)
filter!(row -> !(row.id_rooftop_mesh in id_rooftop_mesh_with_missing), data["rooftop_mesh"])

# bus mesh counts
rez_counts = combine(groupby(data["rez_mesh"], :id_bus), nrow => :n_rez_mesh)
rooftop_counts = combine(groupby(data["rooftop_mesh"], :id_bus), nrow => :n_rooftop_mesh)
bus_mesh_counts = outerjoin(rez_counts, rooftop_counts; on=:id_bus)
add_data_col_by_id!(bus_mesh_counts, bus_to_name; id_col=:id_bus, data_col=:bus_name)
bus_mesh_counts
# 12×3 DataFrame
#  Row │ id_bus  n_rez_mesh  n_rooftop_mesh 
#      │ Int64   Int64       Int64          
# ─────┼────────────────────────────────────
#    1 │      1         239              15
#    2 │      2         119              10
#    3 │      3         113              13
#    4 │      4          87              22
#    5 │      5          67              20
#    6 │      6          35               9
#    7 │      7          15              14
#    8 │      8         131              18
#    9 │      9         143              20
#   10 │     10          71              16
#   11 │     11         180              19
#   12 │     12          53              20

## Wind
rez_windcf_sched = get_wind_thermal_correction_factor(
    rez_ta_df, data["rez_mesh"];
    gen_id_col=:id_rez_mesh,
    altitude_col=nothing,
)
rez_windcf_sched

# Aggregate by bus, unweighted mean across mesh points
rez_windcf_bus = leftjoin(
    rez_windcf_sched,
    select(data["rez_mesh"], :id_rez_mesh, :id_bus, :bus_name, :id_rez, :rez_name);
    on = :id_rez_mesh
)
rez_windcf_bus_mean = combine(
    groupby(rez_windcf_bus, [:scenario, :date, :id_bus, :bus_name, :id_rez, :rez_name]),
    :value => mean => :cf_mean,
    nrow => :n_mesh
)

## LargePV
rez_pvmodcf_largepv_sched = get_pv_module_temperature_correction_factor_nonconservative(
    rez_ta_df, data["rez_mesh"];
    gen_id_col=:id_rez_mesh,
    U0=25.0, U1=6.84,
)
rez_pvmodcf_largepv_sched

# Aggregate by bus, unweighted mean across mesh points
rez_pvmodcf_largepv_bus = leftjoin(
    rez_pvmodcf_largepv_sched,
    select(data["rez_mesh"], :id_rez_mesh, :id_bus, :bus_name, :id_rez, :rez_name);
    on = :id_rez_mesh
)
rez_pvmodcf_largepv_bus_mean = combine(
    groupby(rez_pvmodcf_largepv_bus, [:scenario, :date, :id_bus, :bus_name, :id_rez, :rez_name]),
    :value => mean => :cf_mean,
    nrow => :n_mesh
)

## RooftopPV
rooftop_pvmodcf_roofpv_sched = get_pv_module_temperature_correction_factor_nonconservative(
    rooftop_ta_df, data["rooftop_mesh"];
    gen_id_col=:id_rooftop_mesh,
    U0=25.0, U1=6.84,
)
rooftop_pvmodcf_roofpv_sched

# Aggregate by bus, unweighted mean across mesh points
rooftop_pvmodcf_roofpv_bus = leftjoin(
    rooftop_pvmodcf_roofpv_sched,
    select(data["rooftop_mesh"], :id_rooftop_mesh, :id_bus, :bus_name);
    on = :id_rooftop_mesh
)
rooftop_pvmodcf_roofpv_bus_mean = combine(
    groupby(rooftop_pvmodcf_roofpv_bus, [:scenario, :date, :id_bus, :bus_name]),
    :value => mean => :cf_mean,
    nrow => :n_mesh
)

## Aggregate output formatting
using DataFrames
using CSV
using Statistics

# --- helpers to format aggregate output like: id, id_gen, scenario, date, value ---
# id_gen is looked up from `data["generator"]` using (type, id_bus).
function _bus_to_idgen_map(generator_df::DataFrame, gen_type::AbstractString)
    sub = generator_df[generator_df.type .== gen_type, [:id_bus, :id_gen]]
    @assert nrow(sub) > 0 "No generators found with type == $(repr(gen_type))."
    return Dict(Int(row.id_bus) => Int(row.id_gen) for row in eachrow(sub))
end

# Collapse to true bus-level first (important for REZ meshes: buses span multiple REZs)
function _format_aggregate_for_csv(
    cf_bus_mean::DataFrame,
    bus_to_idgen::Dict{Int,Int};
    drop_missing_idgen::Bool=true,
    date_shift_days::Int=0,
)
    # 1) collapse any extra grouping (e.g. id_rez/rez_name) down to bus
    bus_level = combine(
        groupby(cf_bus_mean, [:scenario, :date, :id_bus]),
        :cf_mean => mean => :value,
    )

    # Keep original CSV-esque date string format, but allow shifting
    if eltype(bus_level.date) <: AbstractString
        fmt = dateformat"yyyy-mm-dd HH:MM:SS"
        dt = DateTime.(String.(bus_level.date), fmt)

        if date_shift_days != 0
            dt = dt .+ Day(date_shift_days)
        end

        # convert back to the same string format for CSV output
        bus_level.date = Dates.format.(dt, fmt)
    else
        # non-string dates: just shift (keeps DateTime/Date type)
        if date_shift_days != 0
            bus_level.date = bus_level.date .+ Day(date_shift_days)
        end
    end

    # 2) map bus -> id_gen (allow missing then drop)
    bus_level.id_gen = get.(Ref(bus_to_idgen), Int.(bus_level.id_bus), missing)

    if drop_missing_idgen
        filter!(row -> !ismissing(row.id_gen), bus_level)
    end

    # 3) final formatting
    bus_level.id_gen = Int.(bus_level.id_gen)
    bus_level.id = bus_level.id_gen
    out = select(bus_level, :id, :id_gen, :scenario, :date, :value)
    sort!(out, [:scenario, :id_gen, :date])
    return out
end

# The date_shift_days is used to make the hot waves event align with demand data
date_shift_days = 22

## Wind
wind_bus_to_idgen = _bus_to_idgen_map(data["generator"], "Wind")
rez_windcf_out = _format_aggregate_for_csv(
    rez_windcf_bus_mean, wind_bus_to_idgen;
    drop_missing_idgen=true, date_shift_days=date_shift_days
)
CSV.write(
    joinpath(outdir, "Generator_cf_aggregate_wind-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"),
    rez_windcf_out
)

## LargePV
largepv_bus_to_idgen = _bus_to_idgen_map(data["generator"], "LargePV")
rez_largepv_out = _format_aggregate_for_csv(
    rez_pvmodcf_largepv_bus_mean, largepv_bus_to_idgen;
    drop_missing_idgen=true, date_shift_days=date_shift_days
)
CSV.write(
    joinpath(outdir, "Generator_cf_aggregate_largepv_pvmod-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"),
    rez_largepv_out
)

## RoofPV
roofpv_bus_to_idgen = _bus_to_idgen_map(data["generator"], "RoofPV")
roofpv_out = _format_aggregate_for_csv(
    rooftop_pvmodcf_roofpv_bus_mean, roofpv_bus_to_idgen;
    drop_missing_idgen=true, date_shift_days=date_shift_days
)

CSV.write(
    joinpath(outdir, "Generator_cf_aggregate_roofpv_pvmod-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"),
    roofpv_out
)

# To check if duplicates still exist or not:
# # no filepath: run in REPL
# function check_out(df, label)
#     println("\n== ", label, " ==")
#     println("cols: ", names(df))
#     println("nrow: ", nrow(df))

#     cols = propertynames(df)  # Symbols

#     # required columns
#     @assert all(c -> c in cols, (:id, :id_gen, :scenario, :date, :value))

#     # no missings (since you dropped)
#     @assert count(ismissing, df.id_gen) == 0
#     @assert count(ismissing, df.value) == 0

#     # uniqueness of timeseries index
#     dup = combine(groupby(df, [:scenario, :id_gen, :date]), nrow => :n)
#     dup = filter(:n => >(1), dup)
#     println("duplicate (scenario,id_gen,date) groups: ", nrow(dup))
#     if nrow(dup) > 0
#         show(first(dup, min(10, nrow(dup)))); println()
#     end

#     println("value min/max: ", extrema(df.value))
#     return nothing
# end

# check_out(rez_windcf_out, "wind aggregate out")
# check_out(rez_largepv_out, "largepv aggregate out")
# check_out(roofpv_out, "roofpv aggregate out")

# To check that our data from PISP actually only has 1 VRE for each type at each bus:
# # no filepath: run in REPL
# using DataFrames

# function check_one_vre_gen_per_bus(gen_type::String)
#     sub = data["generator"][data["generator"].type .== gen_type, [:id_bus, :id_gen]]
#     perbus = combine(groupby(sub, :id_bus), nrow => :n)
#     bad = filter(:n => >(1), perbus)
#     println(gen_type, ": buses=", nrow(perbus), " bad_buses(n>1)=", nrow(bad))
#     if nrow(bad) > 0
#         show(bad, allrows=true, allcols=true); println()
#         # show the actual duplicated rows
#         ids = Set(bad.id_bus)
#         show(filter(:id_bus => in(ids), sub), allrows=true, allcols=true); println()
#     end
#     return nothing
# end

# check_one_vre_gen_per_bus("Wind")
# check_one_vre_gen_per_bus("LargePV")
# check_one_vre_gen_per_bus("RoofPV")
