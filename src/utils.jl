function add_day!(df)
    transform!(df, :date => ByRow(x -> Date(x)) => :day)
end

function date_as_datetime!(df)
    if !(eltype(df.date) <: DateTime)
        df.date = DateTime.(df.date, DateFormat("yyyy-mm-dd HH:MM:SS"))
    end
end

function preprocess_date!(df)
    date_as_datetime!(df)
    add_day!(df)
end

function groupbyd(df::Union{DataFrame,SubDataFrame}, col::Symbol)
    return Dict(g[!, col][1] => g for g in groupby(df, col))
end

function groupby_scenario_at_init_day(df::DataFrame)
    init_time = minimum(df[!, :date])
    init_day = Date(init_time)
    return groupby_scenario_at_day(df, init_day)
end

function groupby_scenario_at_day(df::DataFrame, day::Date)
    df_init_day = subset(df, :day => ByRow(==(day)))
    return groupbyd(df_init_day, :scenario)
end

function groupby_scenario(df::DataFrame)
    return groupbyd(df, :scenario)
end

function show_parameter(df_parameter)
    # NOTE: I don't know why it require println()
    show(df_parameter, allrows=true, allcols=true)
    println()
end

function sort_res_cols(df::DataFrame)
    """
    Sort columns while moving DateTime to first position if present.
    Handles both nested (M_N) and non-nested column names.
    """
    # !WARNING: the sorting commands no longer supported by psy5
    if "DateTime" in names(df)
        other_cols = filter(!=("DateTime"), names(df))
        sorted_cols = sort(other_cols; by=name -> parse.(Int, split(name, "_")))
        return select(df, ["DateTime"; sorted_cols])
    else
        sorted_cols = sort(names(df); by=name -> parse.(Int, split(name, "_")))
        return select(df, sorted_cols)
    end
end

function diff_df(df1::DataFrame, df2::DataFrame; timecol::Symbol=:DateTime)
    # !WARNING: the diff commands no longer supported by psy5
    numeric_names = names(df1, Not(timecol))
    numeric_diff = DataFrame(
        Matrix(select(df1, Not(timecol))) .- Matrix(select(df2, Not(timecol))),
        numeric_names
    )
    return hcat(DataFrame(timecol => df1[!, timecol]), numeric_diff)
end

"""
Create a one-to-many mapping from values in col1 to vectors of values in col2.
Groups all col2 values that share the same col1 value.

# Arguments
- `df::DataFrame`: DataFrame containing the columns
- `col1::Union{Symbol, String}`: Column name to use as keys
- `col2::Union{Symbol, String}`: Column name to use as values (will be grouped)

# Returns
- `OrderedDict`: Dictionary mapping col1 values to vectors of col2 values (one-to-many)
"""
function get_grouped_map_from_df(df::DataFrame, col1::Union{Symbol,String}, col2::Union{Symbol,String})
    result = OrderedDict{Any,Vector{Any}}()
    for row in eachrow(df[!, [col1, col2]])
        key = row[col1]
        value = row[col2]
        if !haskey(result, key)
            result[key] = Any[]
        end
        push!(result[key], value)
    end
    return result
end

"""
    get_map_from_df(df::DataFrame, col1::Union{Symbol,String}, col2::Union{Symbol,String})

Create a one-to-one mapping from values in col1 to values in col2.

Maps each col1 value to its corresponding col2 value. If a col1 value appears 
multiple times with different col2 values, the last occurrence will be used.
For unique one-to-many mappings, use `get_grouped_map_from_df` instead.

# Arguments
- `df::DataFrame`: DataFrame containing the columns
- `col1::Union{Symbol, String}`: Column name to use as keys
- `col2::Union{Symbol, String}`: Column name to use as values

# Returns
- `OrderedDict`: Dictionary mapping col1 values to col2 values (one-to-one)
"""
function get_map_from_df(df::DataFrame, col1::Union{Symbol,String}, col2::Union{Symbol,String})
    return OrderedDict(zip(df[!, col1], df[!, col2]))
end

"""
Create an inverse mapping from one-to-one to one-to-many that groups keys by
their values.

# Arguments
- `forward_map::OrderedDict{K, V}`: Dictionary mapping keys to values

# Returns
- `OrderedDict{V, Vector{K}}`: Dictionary mapping values to vectors of keys
"""
function get_inverse_map(forward_map::OrderedDict{K,V}) where {K,V}
    inverse_map = OrderedDict{V,Vector{K}}()
    for (key, val) in forward_map
        if !haskey(inverse_map, val)
            inverse_map[val] = K[]
        end
        push!(inverse_map[val], key)
    end
    return inverse_map
end

"""
Create a mapping from generator ID to bus ID.

# Arguments
- `df_generator::DataFrame`: DataFrame containing "generator" data

# Returns
- `OrderedDict{Int64, Int64}`: Dictionary mapping generator IDs to bus IDs
"""
function get_gen_to_bus(df_generator::DataFrame)
    return get_map_from_df(df_generator, :id_gen, :id_bus)
end

"""
Create a mapping from bus ID to generator IDs.

# Arguments
- `gen_to_bus::OrderedDict`: Dictionary mapping generator IDs to bus IDs

# Returns
- `OrderedDict{Int64, Vector{Int64}}`: Dictionary mapping bus IDs to vectors of generator IDs
"""
function get_bus_to_gen(gen_to_bus::OrderedDict{Int64,Int64})
    return get_inverse_map(gen_to_bus)
end

"""
Create a mapping from column names to group IDs. For example, map
generator columns to bus IDs.

In psy5, for example, use:

    data_cols = unique(df_ess_e[:, :name])
    ees_col_to_bus = get_col_to_group(data_cols, ess_to_bus)

# Arguments
- `data_cols::Vector{String}`: Vector of column names (e.g., ["1_2", "1_3", "2_1"])
- `com_to_group::OrderedDict`: Dictionary mapping component IDs to group IDs

# Returns
- `OrderedDict`: Dictionary mapping column names to group IDs
"""
function get_col_to_group(data_cols::Vector{String}, com_to_group::OrderedDict)
    # TODO: rename from col as PSY5 no longer use columns
    col_to_group = OrderedDict()
    for col in data_cols
        com_id = parse(Int, split(col, "_")[1])  # Extract com_id from "com_id_sub_id"
        if haskey(com_to_group, com_id)
            col_to_group[col] = com_to_group[com_id]
        end
    end
    return col_to_group
end

"""
Create a mapping from bus IDs to column names.

# Arguments
- `col_to_bus::OrderedDict`: Dictionary mapping column names to bus IDs

# Returns
- `OrderedDict{Int64, Vector{String}}`: Dictionary mapping bus IDs to vectors of column names
"""
function get_group_to_col(col_to_bus::OrderedDict)
    return get_inverse_map(col_to_bus)
end

function get_component_columns(df::DataFrame; timecol::Union{Symbol,String,Nothing}=:DateTime)
    return filter(x -> x != String(timecol), names(df))
end

"""
    sum_by_group(df; name_to_group, name=:name, timecol=:DateTime, group=:name)

Sum DataFrame values by group and time, creating a new DataFrame without modifying the original.

Maps values in the `:name` column to group identifiers using the provided dictionary,
then aggregates `:value` by the specified time column and group.

# Arguments
- `df::DataFrame`: The DataFrame to aggregate. Must contain `:name` and `:value` columns.
- `name_to_group`: Dictionary mapping names to group identifiers.
- `timecol::Symbol=:DateTime`: The time column to group by (default: `:DateTime`).
- `group::Symbol=:name`: The name for the group column to create (default: `:name`).

# Returns
- `DataFrame`: Aggregated DataFrame with columns `[timecol, group, :value]` where `:value` 
  contains the sum for each time-group combination.
"""
function sum_by_group(df; name_to_group, name=:name, timecol=:DateTime, group=:name)
    df_grouped = transform(
        df, name => ByRow(name -> name_to_group[name]) => group, copycols=false
    )
    return combine(groupby(df_grouped, [timecol, group]), :value => sum => :value)
end

"""
    sum_by_group!(df; name_to_group, name=:name, timecol=:DateTime, group=:name)

Sum DataFrame values by group and time, modifying the original DataFrame by adding a group column.

Maps values in the `:name` column to group identifiers using the provided dictionary,
adds the group column to the original DataFrame, then aggregates `:value` by the 
specified time column and group.

# Arguments
- `df::DataFrame`: The DataFrame to aggregate. Must contain `:name` and `:value` columns.
  Will be modified to include the group column.
- `name_to_group`: Dictionary mapping names to group identifiers.
- `timecol::Symbol=:DateTime`: The time column to group by (default: `:DateTime`).
- `group::Symbol=:name`: The name for the group column to create (default: `:name`).

# Returns
- `DataFrame`: Aggregated DataFrame with columns `[timecol, group, :value]` where `:value` 
  contains the sum for each time-group combination.

# Side Effects
Adds a new column (specified by `group` parameter) to the input DataFrame `df`.
"""
function sum_by_group!(df; name_to_group, name=:name, timecol=:DateTime, group=:name)
    transform!(df, name => ByRow(name -> name_to_group[name]) => group)
    return combine(groupby(df, [timecol, group]), :value => sum => :value)
end

"""
    filter_value_from_df(df::DataFrame, col_name::Symbol, col_value::Any)

Filter DataFrame rows where a column equals a specific value using boolean indexing.

Returns a view (SubDataFrame) for memory efficiency. Faster than `subset` approach
but creates an intermediate boolean array. Use this for performance-critical code.

# Arguments
- `df::DataFrame`: The DataFrame to filter.
- `col_name::Symbol`: The column name to filter on.
- `col_value::Any`: The value to match in the specified column.

# Returns
- `SubDataFrame`: A view of the filtered rows.
"""
function filter_value_from_df(df::DataFrame, col_name::Symbol, col_value::Any)
    return @view df[df[!, col_name].==col_value, :]
end

"""
    filter_values_from_df(df::DataFrame, col_name::Symbol, col_values::Vector)

Filter DataFrame rows where a column value is in a collection of values.

Returns a view (SubDataFrame) for memory efficiency. Use this when filtering
by multiple possible values.

# Arguments
- `df::DataFrame`: The DataFrame to filter.
- `col_name::Symbol`: The column name to filter on.
- `col_values::Vector`: The values to match in the specified column.

# Returns
- `SubDataFrame`: A view of the filtered rows.
"""
function filter_values_from_df(df::DataFrame, col_name::Symbol, col_values::Vector)
    return @view df[in.(df[!, col_name], Ref(col_values)), :]
end

"""
    unify_storage_in_bus(df::DataFrame)
Combine multiple storage units at the same bus into a single equivalent unit.
# Arguments
- `df::DataFrame`: DataFrame of storage units.
# Returns
- `DataFrame`: New DataFrame with combined storage units per bus.
"""
function unify_storage_in_bus(df::DataFrame)
    grouped = groupby(df, :id_bus)
    combined_rows = []
    for group in grouped
        total_capacity = sum(group.capacity .* group.n)

        weighted_ch_eff = sum(group.ch_eff .* group.capacity .* group.n) / total_capacity
        weighted_dch_eff = sum(group.dch_eff .* group.capacity .* group.n) / total_capacity

        combined_emax = sum(group.emax .* group.n)

        combined_eini_mwh = sum(group.eini .* group.emax .* group.n / 100)
        combined_eini = (combined_eini_mwh / combined_emax) * 100

        combined_emin_mwh = sum(group.emin .* group.emax .* group.n / 100)
        combined_emin = (combined_emin_mwh / combined_emax) * 100

        combined_row = Dict(
            :id_ess => group[1, :id_bus],
            :name => "Combined_Bus_$(group[1, :id_bus])",
            :alias => "Combined storage at bus $(group[1, :id_bus])",
            :tech => group[1, :tech],
            :type => group[1, :type],
            :capacity => total_capacity,  # total capacity of all units
            :investment => maximum(group.investment),
            :active => minimum(group.active),
            :id_bus => group[1, :id_bus],
            :ch_eff => weighted_ch_eff,
            :dch_eff => weighted_dch_eff,
            :eini => combined_eini,
            :emin => combined_emin,
            :emax => combined_emax,  # total energy capacity
            :pmin => sum(group.pmin .* group.n),  # total power
            :pmax => sum(group.pmax .* group.n),  # total power
            :lmin => sum(group.lmin .* group.n),  # total power
            :lmax => sum(group.lmax .* group.n),  # total power
            :fullout => group[1, :fullout],
            :partialout => group[1, :partialout],
            :mttrfull => group[1, :mttrfull],
            :mttrpart => group[1, :mttrpart],
            :inertia => sum(group.inertia .* group.n),
            :powerfactor => group[1, :powerfactor],
            :ffr => sum(group.ffr .* group.n),
            :pfr => sum(group.pfr .* group.n),
            :res2 => sum(group.res2 .* group.n),
            :res3 => sum(group.res3 .* group.n),
            :fr_db => group[1, :fr_db],
            :fr_ad => group[1, :fr_ad],
            :fr_dt => group[1, :fr_dt],
            :fr_frt => group[1, :fr_frt],
            :fr_fr => group[1, :fr_fr],
            :longitude => group[1, :longitude],
            :latitude => group[1, :latitude],
            :n => 1,  # unify into single unit
            :contingency => group[1, :contingency],
            :PrimeMovers => group[1, :PrimeMovers],
            :DataType => group[1, :DataType],
            :id_area => group[1, :id_area]
        )

        push!(combined_rows, combined_row)
    end

    return DataFrame(combined_rows)
end

function vcat_dfs(dfs)
    if isa(dfs, AbstractDict)
        vect_df = values(dfs)
    else
        vect_df = dfs
    end
    return vcat(vect_df...) |>
           df -> unique(df, [:DateTime, :name]; keep=:last) |>  # keep last in overlap
                 df -> sort(df, [:DateTime, :name])  # sort by DateTime and name
end

function substract_df_long(df1, df2; colname=:name)
    df = leftjoin(df1, df2, on=[:DateTime, colname], makeunique=true, order=:left)
    transform!(df, [:value, :value_1] => (-) => :value)
    select!(df, [:DateTime, colname, :value])
end

"""
    long_to_wide(df::DataFrame;
    time_col::Union{String,Symbol}=:DateTime,
    name_col::Union{String,Symbol}=:name,
    value_col::Union{String,Symbol}=:value,
    time_as_col::Bool=true)
                 time_col::Union{String,Symbol}=:DateTime,
                 name_col::Union{String,Symbol}=:name,
                 value_col::Union{String,Symbol}=:value,
                 time_as_col::Bool=false)

Convert a DataFrame from long format to wide format for PRAS. It needs to be noted that
    the default wide format is different (transposed) from what Sienna table wide format
    is because we this function is designed for SiennaNEM - PRASNEM compatibility.

# Arguments
- `df::DataFrame`: Input DataFrame in long format
- `time_col`: Column name for the date (default: :DateTime)
- `name_col`: Column name containing category names (default: :name)
- `value_col`: Column name containing values (default: :value)
- `time_as_col`: If true (default), time as columns with categories become rows.
              If false, time becomes rows with categories as columns.

# Returns
- `DataFrame`: Wide format DataFrame

# Examples
```julia
# Standard: categories as rows, time as columns
df_wide = long_to_wide(df_long)

# Transposed: time as rows, categories as columns
df_wide_t = long_to_wide(df_long, time_as_col=false)
```
"""
function long_to_wide(df::DataFrame;
    time_col::Union{String,Symbol}=:DateTime,
    name_col::Union{String,Symbol}=:name,
    value_col::Union{String,Symbol}=:value,
    time_as_col::Bool=true)

    unique_times = unique(df[!, time_col])
    unique_names = unique(df[!, name_col])
    if time_as_col
        # Standard mode: categories as rows, time as columns
        result_df = DataFrame(name_col => unique_names)

        for time_point in unique_times
            filtered_rows = filter(row -> row[time_col] == time_point, df)
            result_df[!, Symbol(time_point)] = filtered_rows[!, value_col]
        end
    else
        # Transposed mode: time as rows, categories as columns
        result_df = DataFrame(time_col => unique_times)

        for category in unique_names
            filtered_rows = filter(row -> row[name_col] == category, df)
            result_df[!, Symbol(category)] = filtered_rows[!, value_col]
        end
    end

    return result_df
end
