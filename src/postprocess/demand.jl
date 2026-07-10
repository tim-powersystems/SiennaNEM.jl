"""
    postprocess_demand_power(dfs_realized::Dict, maps::Dict; timecol::Symbol=:DateTime)

Postprocess demand power data by calculating aggregations by bus and area.

# Arguments
- `dfs_realized::Dict`: Dictionary containing realized results with "parameter" key
- `maps::Dict`: Data dictionary containing mappings
- `timecol::Symbol=:DateTime`: Time column name (default: :DateTime)

# Returns
- `Dict{String, Any}`: Dictionary containing postprocessed results:
    - `"dem_pd"`: All demand active power
    - `"bus_dem_pd"`: Demand power aggregated by bus
    - `"area_dem_pd"`: Demand power aggregated by area
"""
function postprocess_demand_power(dfs_realized::Dict, maps::Dict; timecol::Symbol=:DateTime)
    dfs_post = Dict{String,Any}()

    ## Part 1: All Demand
    # Get demand data
    df_dem_pd = dfs_realized["parameter"]["ActivePowerTimeSeriesParameter__PowerLoad"]
    dfs_post["dem_pd"] = df_dem_pd

    # Create mapping from demand names to buses
    dem_to_bus = maps["dem_to_bus"]  # use id_dem
    dem_n_to_bus = get_col_to_group(unique(df_dem_pd[:, :name]), dem_to_bus)  # use id_dem + id_unit

    # Sum by bus
    df_bus_dem_pd = sum_by_group(df_dem_pd; name_to_group=dem_n_to_bus, timecol=timecol)
    dfs_post["bus_dem_pd"] = df_bus_dem_pd

    # Sum by area
    bus_to_area = maps["bus_to_area"]
    df_area_dem_pd = sum_by_group(df_bus_dem_pd; name_to_group=bus_to_area, timecol=timecol)
    dfs_post["area_dem_pd"] = df_area_dem_pd

    return dfs_post
end
