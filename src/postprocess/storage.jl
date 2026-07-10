"""
    postprocess_storage_power(dfs_realized::Dict, maps::Dict; timecol::Symbol=:DateTime)

Postprocess energy storage system data by calculating aggregations by bus and area.

# Arguments
- `dfs_realized::Dict`: Dictionary containing realized results with "variable" key
- `maps::Dict`: Data dictionary containing mappings
- `timecol::Symbol=:DateTime`: Time column name (default: :DateTime)

# Returns
- `Dict{String, Any}`: Dictionary containing postprocessed results:
    - `"ess_e"`: Energy storage energy levels
    - `"ess_ch"`: Energy storage charging power
    - `"ess_dch"`: Energy storage discharging power
    - `"ess_chdch"`: Net charge/discharge power (positive = charging)
    - `"bus_ess_e"`: Storage energy aggregated by bus
    - `"bus_ess_ch"`: Storage charging power aggregated by bus
    - `"bus_ess_dch"`: Storage discharging power aggregated by bus
    - `"bus_ess_chdch"`: Net storage power aggregated by bus
    - `"area_ess_e"`: Storage energy aggregated by area
    - `"area_ess_ch"`: Storage charging power aggregated by area
    - `"area_ess_dch"`: Storage discharging power aggregated by area
    - `"area_ess_chdch"`: Net storage power aggregated by area
"""
function postprocess_storage_power(dfs_realized::Dict, maps::Dict; timecol::Symbol=:DateTime)
    dfs_post = Dict{String,Any}()

    ## Energy Storage System Shortage and Surplus (Energy Target)
    # timecol_target = :time_index
    # ess_threshold = 1e-6
    # df_ess_shortage = rename(
    #     dfs_res_["variable"]["StorageEnergyShortageVariable__EnergyReservoirStorage"],
    #     :value => :shortage
    # )
    # df_ess_surplus = rename(
    #     dfs_res_["variable"]["StorageEnergySurplusVariable__EnergyReservoirStorage"],
    #     :value => :surplus
    # )
    # df_ess_target = leftjoin(
    #     df_ess_shortage,
    #     df_ess_surplus,
    #     on=[timecol_target, :name],
    #     order=:left
    # )

    # # TODO: Check why there are some shortage/surplus values
    # if any(df_ess_target.shortage .> 1e-6)
    #     println("Warning: Energy shortage detected in storage!")
    # end
    # if any(df_ess_target.surplus .> 1e-6)
    #     println("Warning: Energy surplus detected in storage!")
    # end

    # df_ess_target = filter(
    #     row -> row.shortage > ess_threshold || row.surplus > ess_threshold,
    #     df_ess_target
    # )
    # if nrow(df_ess_target) > 0
    #     println(df_ess_target)
    # end

    ## Part 1: All Energy Storage Systems
    # Get ESS data
    df_ess_e = dfs_realized["variable"]["EnergyVariable__EnergyReservoirStorage"]
    df_ess_ch = dfs_realized["variable"]["ActivePowerInVariable__EnergyReservoirStorage"]
    df_ess_dch = dfs_realized["variable"]["ActivePowerOutVariable__EnergyReservoirStorage"]

    # Store individual ESS data
    dfs_post["ess_e"] = df_ess_e
    dfs_post["ess_ch"] = df_ess_ch
    dfs_post["ess_dch"] = df_ess_dch

    # Calculate net charge/discharge (positive = charging, negative = discharging)
    df_ess_chdch = copy(df_ess_ch)
    df_ess_chdch.value = df_ess_ch.value .- df_ess_dch.value
    dfs_post["ess_chdch"] = df_ess_chdch

    # Create mapping from ESS names to buses
    ess_to_bus = maps["ess_to_bus"]  # use id_ess
    ess_n_to_bus = get_col_to_group(unique(df_ess_e[:, :name]), ess_to_bus)  # use id_ess + id_unit

    # Sum by bus
    df_bus_ess_e = sum_by_group(df_ess_e; name_to_group=ess_n_to_bus, timecol=timecol)
    df_bus_ess_ch = sum_by_group(df_ess_ch; name_to_group=ess_n_to_bus, timecol=timecol)
    df_bus_ess_dch = sum_by_group(df_ess_dch; name_to_group=ess_n_to_bus, timecol=timecol)
    df_bus_ess_chdch = sum_by_group(df_ess_chdch; name_to_group=ess_n_to_bus, timecol=timecol)

    dfs_post["bus_ess_e"] = df_bus_ess_e
    dfs_post["bus_ess_ch"] = df_bus_ess_ch
    dfs_post["bus_ess_dch"] = df_bus_ess_dch
    dfs_post["bus_ess_chdch"] = df_bus_ess_chdch

    # Sum by area
    bus_to_area = maps["bus_to_area"]
    df_area_ess_e = sum_by_group(df_bus_ess_e; name_to_group=bus_to_area, timecol=timecol)
    df_area_ess_ch = sum_by_group(df_bus_ess_ch; name_to_group=bus_to_area, timecol=timecol)
    df_area_ess_dch = sum_by_group(df_bus_ess_dch; name_to_group=bus_to_area, timecol=timecol)
    df_area_ess_chdch = sum_by_group(df_bus_ess_chdch; name_to_group=bus_to_area, timecol=timecol)

    dfs_post["area_ess_e"] = df_area_ess_e
    dfs_post["area_ess_ch"] = df_area_ess_ch
    dfs_post["area_ess_dch"] = df_area_ess_dch
    dfs_post["area_ess_chdch"] = df_area_ess_chdch

    ## Part 2: Detailed ESS Analysis (df_ess)
    # Create comprehensive ESS dataframe with all variables
    df_ess = copy(df_ess_e)
    DF.rename!(df_ess, :value => :energy)

    # Add charge and discharge power
    df_ess = leftjoin(
        df_ess,
        DF.rename(df_ess_ch, :value => :charge_power),
        on=[timecol, :name],
        order=:left,
    )

    df_ess = leftjoin(
        df_ess,
        DF.rename(df_ess_dch, :value => :discharge_power),
        on=[timecol, :name],
        order=:left,
    )

    # Calculate net power (positive = charging, negative = discharging)
    df_ess.net_power = df_ess.charge_power .- df_ess.discharge_power

    # # Add ESS parameters if available
    # if haskey(data, "map") && haskey(data["map"], "ess_unit_to_emax")
    #     ess_unit_to_emax = data["map"]["ess_unit_to_emax"]
    #     ess_unit_to_pmax_ch = get(data["map"], "ess_unit_to_pmax_ch", Dict())
    #     ess_unit_to_pmax_dch = get(data["map"], "ess_unit_to_pmax_dch", Dict())
        
    #     df_ess.maximum_energy = [get(ess_unit_to_emax, name, 0.0) for name in df_ess.name]
    #     df_ess.maximum_charge_power = [get(ess_unit_to_pmax_ch, name, 0.0) for name in df_ess.name]
    #     df_ess.maximum_discharge_power = [get(ess_unit_to_pmax_dch, name, 0.0) for name in df_ess.name]
        
    #     # Check violations
    #     threshold = 1e-6
    #     df_ess.energy_violation = (df_ess.energy .- df_ess.maximum_energy) .> threshold
    #     df_ess.charge_violation = (df_ess.charge_power .- df_ess.maximum_charge_power) .> threshold
    #     df_ess.discharge_violation = (df_ess.discharge_power .- df_ess.maximum_discharge_power) .> threshold
        
    #     if any(df_ess.energy_violation .| df_ess.charge_violation .| df_ess.discharge_violation)
    #         println("Warning: ESS constraint violations detected.")
    #         println(filter(row -> row.energy_violation || row.charge_violation || row.discharge_violation, df_ess))
    #     end
    # end

    # Store detailed ESS data
    dfs_post["ess"] = df_ess

    return dfs_post
end
