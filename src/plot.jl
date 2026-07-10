using PlotlyJS

"""
    plot_stacked_wide(df::DataFrame, id_to_name::Union{OrderedDict, Dict}; 
                      timecol::Symbol=:DateTime, title::String="Stacked Area Chart", 
                      yaxis_title::String="Value (MW)")

Plot stacked area chart from wide-format DataFrame where each column represents a unit.

# Arguments
- `df::DataFrame`: DataFrame with time column and data columns (named by ID)
- `id_to_name::Union{OrderedDict, Dict}`: Mapping from IDs to display names
- `timecol::Symbol`: Name of the time column (default: `:DateTime`)
- `title::String`: Plot title
- `yaxis_title::String`: Y-axis label (default: "Value (MW)")

# Returns
- PlotlyJS plot object

# Format
Wide format expects columns like: `DateTime | 1 | 2 | 3 | ...`
where each numbered column represents a different unit/bus/area.
"""
function plot_stacked_wide(
    df::DataFrame,
    id_to_name::Union{OrderedDict,Dict};
    timecol::Symbol=:DateTime,
    title::String="Stacked Area Chart",
    yaxis_title::String="Value (MW)"
)
    # Get time column
    time_data = df[!, timecol]
    
    # Get all data columns (excluding time column)
    data_cols = [col for col in names(df) if col != String(timecol)]
    
    # Create traces for each column
    traces = GenericTrace[]
    for col in reverse(data_cols)
        col_id = parse(Int, col)
        display_name = get(id_to_name, col_id, "ID $col")  # Fallback to ID if name not found
        
        trace = scatter(
            x=time_data,
            y=df[!, col],
            name=display_name,
            mode="lines",
            stackgroup="one",
            fillcolor="tozeroy"
        )
        push!(traces, trace)
    end
    
    # Create layout
    layout = Layout(
        title=title,
        xaxis_title="Time",
        yaxis_title=yaxis_title,
        hovermode="x unified",
        legend=attr(orientation="v", yanchor="top", y=1, xanchor="left", x=1.02)
    )
    
    plot(traces, layout)
end

"""
    plot_stacked_long(df::DataFrame, id_to_name::Union{OrderedDict, Dict}; 
                      timecol::Symbol=:DateTime, namecol::Symbol=:name, 
                      valuecol::Symbol=:value, title::String="Stacked Area Chart", 
                      yaxis_title::String="Value (MW)")

Plot stacked area chart from long-format DataFrame with columns for time, name, and value.

# Arguments
- `df::DataFrame`: DataFrame in long format with time, name, and value columns
- `id_to_name::Union{OrderedDict, Dict}`: Mapping from IDs/names to display names
- `timecol::Symbol`: Name of the time column (default: `:DateTime`)
- `namecol::Symbol`: Name of the identifier column (default: `:name`)
- `valuecol::Symbol`: Name of the value column (default: `:value`)
- `title::String`: Plot title
- `yaxis_title::String`: Y-axis label (default: "Value (MW)")

# Returns
- PlotlyJS plot object

# Format
Long format expects three columns: `DateTime | name | value`
where multiple rows share the same DateTime but have different names.
"""
function plot_stacked_long(
    df::DataFrame,
    id_to_name::Union{OrderedDict,Dict};
    timecol::Symbol=:DateTime,
    namecol::Symbol=:name,
    valuecol::Symbol=:value,
    title::String="Stacked Area Chart",
    yaxis_title::String="Value (MW)"
)
    # Get unique names/IDs
    unique_names = unique(df[!, namecol])
    
    # Create traces for each unique name
    traces = GenericTrace[]
    for name in reverse(unique_names)
        # Filter data for this name
        mask = df[!, namecol] .== name
        time_data = df[mask, timecol]
        value_data = df[mask, valuecol]
        
        # Get display name
        display_name = get(id_to_name, name, string(name))  # Fallback to name itself
        
        trace = scatter(
            x=time_data,
            y=value_data,
            name=display_name,
            mode="lines",
            stackgroup="one",
            fillcolor="tozeroy"
        )
        push!(traces, trace)
    end
    
    # Create layout
    layout = Layout(
        title=title,
        xaxis_title="Time",
        yaxis_title=yaxis_title,
        hovermode="x unified",
        legend=attr(orientation="v", yanchor="top", y=1, xanchor="left", x=1.02)
    )
    
    plot(traces, layout)
end

"""
    plot_stacked(df::DataFrame, id_to_name::Union{OrderedDict, Dict}; 
                 timecol::Symbol=:DateTime, namecol::Symbol=:name, 
                 valuecol::Symbol=:value, title::String="Stacked Area Chart", 
                 yaxis_title::String="Value (MW)")

Plot stacked area chart. Defaults to long format (calls `plot_stacked_long`).

# Arguments
- `df::DataFrame`: DataFrame in long format (DateTime | name | value)
- `id_to_name::Union{OrderedDict, Dict}`: Mapping from IDs/names to display names
- `timecol::Symbol`: Name of the time column (default: `:DateTime`)
- `namecol::Symbol`: Name of the identifier column (default: `:name`)
- `valuecol::Symbol`: Name of the value column (default: `:value`)
- `title::String`: Plot title
- `yaxis_title::String`: Y-axis label (default: "Value (MW)")

# Returns
- PlotlyJS plot object

# See Also
- `plot_stacked_long`: For long-format DataFrames (DateTime | name | value)
- `plot_stacked_wide`: For wide-format DataFrames (DateTime | 1 | 2 | 3 | ...)
"""
function plot_stacked(
    df::DataFrame,
    id_to_name::Union{OrderedDict,Dict};
    timecol::Symbol=:DateTime,
    namecol::Symbol=:name,
    valuecol::Symbol=:value,
    title::String="Stacked Area Chart",
    yaxis_title::String="Value (MW)",
    df_format::Symbol=:long  # :long or :wide
)
    if df_format == :long
        return plot_stacked_long(
            df, id_to_name;
            timecol=timecol,
            namecol=namecol,
            valuecol=valuecol,
            title=title,
            yaxis_title=yaxis_title
        )
    end

    if df_format == :wide
        return plot_stacked_wide(
            df, id_to_name;
            timecol=timecol,
            title=title,
            yaxis_title=yaxis_title
        )
    end
end
