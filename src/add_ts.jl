"""
Clean the time series data by removing rows with missing values in the `:name` column.

# Arguments
- `data::Dict{String,Any}`: A dictionary containing the data. It must include:
    - `data["generator"]`: DataFrame with generator information.
    - `data["generator_pmax_ts"]`: DataFrame with generator time series.

# Modifies
- `data["generator_pmax_ts"]`: Updates the time series data after cleaning.
"""
function clean_ts_data!(data::Dict{String,Any})
    df_generator = data["generator"]
    df_generator_ts = data["generator_pmax_ts"]

    # Remove rows with missing `:name` in the generator time series, due to id_gen == 78
    unique_id_gen_ts = unique(df_generator_ts[:, :id_gen]) 
    df_generator_ts_unique_id_gen = DataFrame(id_gen=unique_id_gen_ts)
    df_generator_ts_unique_id_gen = leftjoin(
        df_generator_ts_unique_id_gen,
        df_generator[:, [:id_gen, :name, :tech, :DataType]], on=:id_gen, order=:left
    )
    df_generator_ts_unique_id_gen = dropmissing(df_generator_ts_unique_id_gen, :name)
    unique_id_gen_ts = df_generator_ts_unique_id_gen[:, :id_gen]
    df_generator_ts = filter(row -> row.id_gen in unique_id_gen_ts, df_generator_ts)
    data["generator_pmax_ts"] = df_generator_ts
end

"""
Add time series data to the system.

# Arguments
- `sys`: The system object to which time series data will be added.
- `data`: A dictionary containing time series data and components.
- `horizon`: The time horizon for the time series (optional).
- `interval`: The interval between time steps (optional).
- `scenario`: The scenario name or index (default: 1).

# Modifies
- `sys`: Adds time series data to the system.
"""
function add_ts!(
    sys, data;
    start_date=nothing,
    horizon=nothing,
    interval=Hour(1),
    scenario=1
)
    # NOTE: This is just a wrapper to use data instead of df

    # Get specific scenario
    df_demand_ts = filter_value_from_df(data["demand_l_ts"], :scenario, scenario)
    df_generator_ts = filter_value_from_df(data["generator_pmax_ts"], :scenario, scenario)

    # Get specific time slice
    if start_date !== nothing
        if horizon === nothing
            slice_end = maximum(df_demand_ts[!, :date])
        else
            slice_end = start_date + horizon
        end

        df_demand_ts = get_time_slice(df_demand_ts, initial_time=start_date, slice_end=slice_end)
        df_generator_ts = get_time_slice(df_generator_ts, initial_time=start_date, slice_end=slice_end)
    end

    add_ts!(
        sys,
        df_demand_ts,
        df_generator_ts,
        data["components"]["demands"],
        data["components"]["renewable_dispatch_generators"],
        data["components"]["renewable_nondispatch_generators"];
        horizon=horizon,
        interval=interval,
    )
end

function add_ts!(
    sys,
    df_demand_ts,
    df_generator_ts,
    demands,
    renewable_dispatch_generators,
    renewable_nondispatch_generators;
    horizon=nothing,
    interval=Hour(1),
)
    # NOTE:
    #   This is the main function to add time series to the system.
    #   Slicing the data should be done outside this function.
    #   This function also didn't use groupbyd, the data should be already single scenario.
    #   The format of df_demand_ts and df_generator_ts should follow PISP.jl format:
    #       df_demand_ts: [:id_dem, :date, :value]
    #       df_generator_ts: [:id_gen, :date, :value]
    # 
    #   Data :value is in MW.

    # Add demand time series
    grouped_demand = groupbyd(df_demand_ts, :id_dem)
    grouped_generator = groupbyd(df_generator_ts, :id_gen)
    add_sts!(sys, demands, grouped_demand, :id_dem)
    add_sts!(sys, renewable_dispatch_generators, grouped_generator, :id_gen)
    add_sts!(sys, renewable_nondispatch_generators, grouped_generator, :id_gen)

    # Auto-detect horizon and interval if not provided
    if horizon === nothing
        first_key = first(keys(grouped_demand))
        dates = grouped_demand[first_key][!, :date]
        horizon = dates[end] - dates[1]
    end

    transform_single_time_series!(
        sys,
        horizon,
        interval,  # interval is not resolution, this is used for the rolling forecast window time step
    )
end

# TODO:
#   1. Support multiple ts
#   2. Normalize data in p.u. not in here, but in reading data
function add_sts!(
    sys::PSY.System,
    instances::Dict{Int, T},
    dfs,
    col::Symbol,
) where {T <: PSY.PowerLoad}
    # NOTE: Dict{Int, T}, used for demands
    units_base_system = get_units_base(sys)
    set_units_base_system!(sys, "NATURAL_UNITS")
    for (sym_id, instance) in instances
        df = copy(dfs[sym_id][:, [col, :date, :value]])
        df.value .= df.value ./ get_max_active_power(instance)
        add_st!(sys, instance, df)
    end
    set_units_base_system!(sys, units_base_system)
end

function add_st!(
    sys::PSY.System,
    instance::PSY.PowerLoad,
    df::Union{DataFrame, SubDataFrame};
    scaling_factor_multiplier=get_max_active_power,
)
    # NOTE: df.value must be already normalized
    ta = TimeArray(df[:, [:date, :value]], timestamp=:date)
    sts = SingleTimeSeries(;
        name="max_active_power",  # 1 means first row
        data=ta,
        scaling_factor_multiplier=scaling_factor_multiplier,
    )
    add_time_series!(sys, instance, sts);
end

function add_sts!(
    sys::PSY.System,
    nested_instances::Dict{Int,Dict{Int,T}},
    dfs,
    col::Symbol,
) where {T <: PSY.RenewableGen}
    # NOTE: Dict{Int,Dict{Int,T}}, used for generators
    units_base_system = get_units_base(sys)
    set_units_base_system!(sys, "NATURAL_UNITS")
    for (sym_id, instances) in nested_instances
        df = copy(dfs[sym_id][:, [col, :date, :value]])
        max_active_power = get_max_active_power(first(values(instances)))
        df.value .= df.value ./ max_active_power
        add_st!(sys, instances, df)
    end
    set_units_base_system!(sys, units_base_system)
end

function add_st!(
    sys::PSY.System,
    instances::Dict{Int,T},
    df::Union{SubDataFrame, DataFrame};
    scaling_factor_multiplier=get_max_active_power,
) where {T <: PSY.RenewableGen}
    # NOTE: df must be already normalized
    ta = TimeArray(df[:, [:date, :value]], timestamp=:date)
    sts = SingleTimeSeries(;
        name="max_active_power",  # 1 means first row
        data=ta,
        scaling_factor_multiplier=scaling_factor_multiplier,
    )
    add_time_series!(sys, values(instances), sts);
end


function get_time_slice(
    df::Union{DataFrame, SubDataFrame};
    initial_time::DateTime,
    slice_end::DateTime,
)
    # Use @view macro for zero-copy slicing
    indices = findall(row -> initial_time <= row.date < slice_end, eachrow(df))
    return @view df[indices, :]
end


"""
Iterator version - memory efficient, use when processing sequentially.
"""
function get_time_slices_iterator(
    df::Union{DataFrame, SubDataFrame};
    initial_time::DateTime,
    horizon::Period,
    window_shift::Period,
)
    max_date = maximum(df.date)
    
    return Channel() do ch
        current_time = initial_time
        
        while current_time < max_date
            slice_end = current_time + horizon
            put!(ch, (current_time, get_time_slice(df, initial_time=current_time, slice_end=slice_end)))
            current_time += window_shift
        end
    end
end
