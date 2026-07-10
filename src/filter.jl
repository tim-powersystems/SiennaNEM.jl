function filter_active(df)
    """
    Filter rows where the 'active' column is equal to 1.
    """
    return filter(r -> r.active == 1, df)
end

function filter_active_with_min_units(df, min_units::Int=1)
    """
    Filter rows where the 'active' column is equal to 1 and 'n' column is
    greater than or equal to min_units.
    """
    return filter(r -> r.active == 1 && r.n >= min_units, df)
end

function filter_in_date_range(df; start_date::Date, end_date::Date, datecol::Symbol=:DateTime)
    """
    Filter rows where the 'DateTime' column falls within the specified date range.
    """
    date_range = start_date:Day(1):end_date
    return filter(r -> Date(r[datecol]) in date_range, df)
end

function filter_in_date_range(df; date_range::UnitRange{Date}, datecol::Symbol=:DateTime)
    """
    Filter rows where the 'DateTime' column falls within the specified date range.
    """
    return filter(r -> Date(r[datecol]) in date_range, df)
end

function filter_in_date(df; date, datecol::Symbol=:DateTime)
    """
    Filter rows where the 'DateTime' column matches the specified date.
    """
    return filter(r -> Date(r[datecol]) == Date(date), df)
end

"""
    filter_by_year(df, year::Int; datecol::Symbol=:DateTime)

Filter DataFrame rows where the date column matches the specified year.

# Arguments
- `df`: The DataFrame to filter
- `year::Int`: The year to filter by (e.g., 2030, 2044)
- `datecol::Symbol`: Name of the date column (default: `:date`)

# Returns
- `DataFrame`: Filtered DataFrame containing only rows from the specified year
"""
function filter_in_year(df; year::Int, datecol::Symbol=:date)
    return filter(r -> Dates.year(Date(r[datecol])) == year, df)
end

# TODO:
# add filter to find lowest VRE output
# 
# combine(
#     groupby(
#         filter_in_year(df_generator_ts; year=2030, datecol=:date),
#         [:scenario, :day]
#     ),
#     :value => sum => :value
# ) |> df -> sort(df, :value)
# 
# 365×3 DataFrame
#  Row │ scenario  day         value          
#      │ Int64     Date        Float64        
# ─────┼──────────────────────────────────────
#    1 │        1  2030-06-05       2.15977e5
#    2 │        1  2030-07-05       2.38808e5
#    3 │        1  2030-05-28       2.42667e5
