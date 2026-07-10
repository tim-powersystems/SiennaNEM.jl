"""
    postprocess_generator_power(dfs_realized::Dict, maps::Dict; timecol::Symbol=:DateTime, threshold::Float64=1e-6)

Postprocess generator power data by calculating aggregations by bus and area,
and computing primary frequency response for thermal generators.

# Arguments
- `dfs_realized::Dict`: Dictionary containing realized results with "variable" and "parameter" keys
- `maps::Dict`: Data dictionary containing mappings
- `timecol::Symbol=:DateTime`: Time column name (default: :DateTime)
- `threshold::Float64=1e-6`: Threshold for detecting pmax violations (default: 1e-6)

# Returns
- `Dict{String, Any}`: Dictionary containing postprocessed results:
    - `"gen_pg"`: All generator active power
    - `"bus_gen_pg"`: Generator power aggregated by bus
    - `"area_gen_pg"`: Generator power aggregated by area
    - `"tgen"`: Thermal generator details with PFR calculations
    - `"bus_tgen_pfr"`: Thermal generator PFR aggregated by bus
    - `"area_tgen_pfr"`: Thermal generator PFR aggregated by area

# Side Effects
Prints warnings if thermal generators violate pmax constraints.
"""
function postprocess_generator_power(dfs_realized::Dict, maps::Dict; timecol::Symbol=:DateTime, threshold::Float64=1e-6)
    dfs_post = Dict{String,Any}()

    ## Part 1: All Generators (df_gen_pg)
    # Combine all generation data
    df_gen_pg = vcat(
        dfs_realized["variable"]["ActivePowerVariable__ThermalStandard"],
        dfs_realized["variable"]["ActivePowerVariable__RenewableDispatch"],
        dfs_realized["parameter"]["ActivePowerTimeSeriesParameter__RenewableNonDispatch"],
    )
    dfs_post["gen_pg"] = df_gen_pg

    # Create mapping from generator names to buses
    gen_to_bus = maps["gen_to_bus"]  # use id_gen
    gen_n_to_bus = get_col_to_group(unique(df_gen_pg[:, :name]), gen_to_bus)  # use id_gen + id_unit

    # Sum by bus
    df_bus_gen_pg = sum_by_group(df_gen_pg; name_to_group=gen_n_to_bus, timecol=timecol)
    dfs_post["bus_gen_pg"] = df_bus_gen_pg

    # Sum by area
    bus_to_area = maps["bus_to_area"]
    df_area_gen_pg = sum_by_group(df_bus_gen_pg; name_to_group=bus_to_area, timecol=timecol)
    dfs_post["area_gen_pg"] = df_area_gen_pg

    ## Part 2: Thermal Standard Generators (df_tgen)
    # Start with thermal generator active power
    df_tgen = copy(dfs_realized["variable"]["ActivePowerVariable__ThermalStandard"])
    DF.rename!(df_tgen, :value => :active_power)

    # Add unit commitment
    df_gen_unit_commitment = dfs_realized["variable"]["OnVariable__ThermalStandard"]
    df_tgen = leftjoin(
        df_tgen,
        DF.rename(df_gen_unit_commitment, :value => :unit_commitment),
        on=[timecol, :name],
        order=:left,
    )

    # Add generator parameters (pmax and pfrmax)
    gen_unit_to_pmax = maps["gen_unit_to_pmax"]
    gen_unit_to_pfrmax = maps["gen_unit_to_pfrmax"]
    df_tgen.maximum_active_power = [get(gen_unit_to_pmax, name, 0.0) for name in df_tgen.name]
    df_tgen.maximum_primary_frequency_response = [get(gen_unit_to_pfrmax, name, 0.0) for name in df_tgen.name]

    # Calculate available capacity and PFR allocation
    df_tgen.available_capacity = (df_tgen.maximum_active_power .* df_tgen.unit_commitment) .- df_tgen.active_power
    df_tgen.pfr_limit = df_tgen.maximum_primary_frequency_response .* df_tgen.unit_commitment
    df_tgen.primary_frequency_response = max.(min.(df_tgen.available_capacity, df_tgen.pfr_limit), 0.0)

    # Store df_tgen
    dfs_post["tgen"] = df_tgen

    # Create df_tgen_pg by selecting columns from df_tgen
    df_tgen_pg = select(df_tgen, timecol, :name, :primary_frequency_response => :value)

    # Sum by bus
    df_bus_tgen_pfr = sum_by_group(df_tgen_pg; name_to_group=gen_n_to_bus, timecol=timecol)
    dfs_post["bus_tgen_pfr"] = df_bus_tgen_pfr

    # Sum by Area
    df_area_tgen_pfr = sum_by_group(df_bus_tgen_pfr; name_to_group=bus_to_area, timecol=timecol)
    dfs_post["area_tgen_pfr"] = df_area_tgen_pfr

    ## Check violation for thermal generators
    df_tgen.violation = (df_tgen.active_power .- df_tgen.maximum_active_power) .> threshold

    if any(df_tgen.violation)
        println("Warning: Violations against pmax detected.")
        println(filter(row -> row.violation, df_tgen))
    end

    return dfs_post
end
