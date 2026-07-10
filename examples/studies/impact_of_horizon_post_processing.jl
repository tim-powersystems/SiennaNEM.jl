using DataFrames, OrderedCollections

# create optimization_outputs dictionary
optimization_outputs = Dict{String,Any}()
for (k, v) in results
    optimization_outputs[string(k)] = get_results_dataframes(v)
end

# replace variable with realized variable
# !WARNING this is not good as it replace variable with realized_variables
k = "72_rolling"
if haskey(results, k)
    optimization_outputs[k]["variable"] = read_realized_variables(results[k])
end

# create results_post dictionary
filter_at_target_day = true
timecol = :DateTime
bus_to_area = get_map_from_df(data["bus"], :id_bus, :id_area)
results_post = Dict{String,Any}()
for (k, dfs_res) in optimization_outputs
    # There must be no shortage and surplus energy to ensure the problem feasible
    if haskey(dfs_res["variable"], "StorageEnergyShortageVariable__EnergyReservoirStorage")
        row_sums_shortage = sum.(eachrow(select(dfs_res["variable"]["StorageEnergyShortageVariable__EnergyReservoirStorage"])))
        row_sums_surplus = sum.(eachrow(select(dfs_res["variable"]["StorageEnergySurplusVariable__EnergyReservoirStorage"])))
    end

    ## Create Aggregated Energy Storage Energy
    # Get df
    df_ess_e = dfs_res["variable"]["EnergyVariable__EnergyReservoirStorage"]
    df_ess_ch = dfs_res["variable"]["ActivePowerInVariable__EnergyReservoirStorage"]
    df_ess_dch = dfs_res["variable"]["ActivePowerOutVariable__EnergyReservoirStorage"]

    if filter_at_target_day
        df_ess_e = filter(r -> Date(r.DateTime) == Date(target_day), df_ess_e)
        df_ess_ch = filter(r -> Date(r.DateTime) == Date(target_day), df_ess_ch)
        df_ess_dch = filter(r -> Date(r.DateTime) == Date(target_day), df_ess_dch)
    end

    # Get map
    ess_to_bus = get_map_from_df(data["storage"], :id_ess, :id_bus)  # use id_gen
    ees_n_to_bus = get_col_to_group(unique(df_ess_e[:, :name]), ess_to_bus)  # use id_ess + id_unit

    # Sum columns for each bus
    df_bus_ess_e = sum_by_group(df_ess_e, name_to_group=ees_n_to_bus, group=:bus)
    df_bus_ess_ch = sum_by_group(df_ess_ch, name_to_group=ees_n_to_bus, group=:bus)
    df_bus_ess_dch = sum_by_group(df_ess_dch, name_to_group=ees_n_to_bus, group=:bus)

    df_bus_ess_chdch = copy(df_bus_ess_ch)
    df_bus_ess_chdch.value = df_bus_ess_ch.value - df_bus_ess_dch.value

    # Sum columns for each area
    df_area_ess_e = sum_by_group(df_bus_ess_e, name=:bus, name_to_group=bus_to_area, group=:area)
    df_area_ess_ch = sum_by_group(df_bus_ess_ch, name=:bus, name_to_group=bus_to_area, group=:area)
    df_area_ess_dch = sum_by_group(df_bus_ess_dch, name=:bus, name_to_group=bus_to_area, group=:area)
    df_area_ess_chdch = sum_by_group(df_bus_ess_chdch, name=:bus, name_to_group=bus_to_area, group=:area)

    # get df_vre_pc
    vred_param_df = isa(dfs_res["parameter"]["ActivePowerTimeSeriesParameter__RenewableDispatch"], AbstractDict) ?
                    vcat_dfs(dfs_res["parameter"]["ActivePowerTimeSeriesParameter__RenewableDispatch"]) :
                    dfs_res["parameter"]["ActivePowerTimeSeriesParameter__RenewableDispatch"]
    vred_var_df = dfs_res["variable"]["ActivePowerVariable__RenewableDispatch"]
    vrend_param_df = isa(dfs_res["parameter"]["ActivePowerTimeSeriesParameter__RenewableNonDispatch"], AbstractDict) ?
                     vcat_dfs(dfs_res["parameter"]["ActivePowerTimeSeriesParameter__RenewableNonDispatch"]) :
                     dfs_res["parameter"]["ActivePowerTimeSeriesParameter__RenewableNonDispatch"]
    df_tgen_pg = dfs_res["variable"]["ActivePowerVariable__ThermalStandard"]

    if filter_at_target_day
        vred_param_df = filter(r -> Date(r.DateTime) == Date(target_day), vred_param_df)
        vred_var_df = filter(r -> Date(r.DateTime) == Date(target_day), vred_var_df)
        df_tgen_pg = filter(r -> Date(r.DateTime) == Date(target_day), df_tgen_pg)
    end

    # df_gen
    df_gen_pg = vcat_dfs([
        df_tgen_pg,  # ThermalStandard
        vrend_param_df,  # RenewableNonDispatch
        vred_var_df,  # RenewableDispatch
    ])

    # bus and area
    gen_to_bus = get_map_from_df(data["generator"], :id_gen, :id_bus)
    gen_n_to_bus = get_col_to_group(unique(df_gen_pg[:, :name]), gen_to_bus)  # use id_gen + id_unit

    df_bus_tgen_pg = sum_by_group(df_tgen_pg, name_to_group=gen_n_to_bus, group=:bus)
    df_area_tgen_pg = sum_by_group(df_bus_tgen_pg, name=:bus, name_to_group=bus_to_area, group=:area)
    df_bus_gen_pg = sum_by_group(df_gen_pg, name_to_group=gen_n_to_bus, group=:bus)
    df_area_gen_pg = sum_by_group(df_bus_gen_pg, name=:bus, name_to_group=bus_to_area, group=:area)

    # VRE curtailment
    df_vre_pc = substract_df_long(vred_param_df, vred_var_df)  # curtailment
    df_bus_vre_pc = sum_by_group(df_vre_pc, name_to_group=gen_n_to_bus, group=:bus)
    df_area_vre_pc = sum_by_group(df_bus_vre_pc, name=:bus, name_to_group=bus_to_area, group=:area)

    # Store
    results_post[k] = Dict(
        "bus_ess_e" => df_bus_ess_e,
        "bus_ess_ch" => df_bus_ess_ch,
        "bus_ess_dch" => df_bus_ess_dch,
        "bus_ess_chdch" => df_bus_ess_chdch,
        "bus_gen_pg" => df_bus_gen_pg,
        "bus_vre_pc" => df_bus_vre_pc,
        "bus_tgen_pg" => df_bus_tgen_pg,
        "area_ess_e" => df_area_ess_e,
        "area_ess_ch" => df_area_ess_ch,
        "area_ess_dch" => df_area_ess_dch,
        "area_ess_chdch" => df_area_ess_chdch,
        "area_gen_pg" => df_area_gen_pg,
        "area_vre_pc" => df_area_vre_pc,
        "area_tgen_pg" => df_area_tgen_pg,
        # bus_gen_pfr
        # area_gen_pfr
    )
end
