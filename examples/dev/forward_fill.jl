using SiennaNEM

using Dates

# Load data
reference_trace = 4006
poe = 10
tyear = 2025
file_format = "arrow"
system_data_dir = joinpath(
    @__DIR__, "../..", "NEM-reliability-suite", "data", "pisp-datasets",
    "out-ref$reference_trace-poe$poe", file_format
)
ts_data_dir = joinpath(system_data_dir, "schedule-$tyear")
data = read_system_data(system_data_dir)
read_ts_data!(data, ts_data_dir)

df_bus = data["bus"]
df_generator = data["generator"]
df_line = data["line"]
df_demand = data["demand"]
df_storage = data["storage"]

df_demand_l_ts = data["demand_l_ts"]
df_generator_pmax_ts = data["generator_pmax_ts"]
df_generator_n_ts = data["generator_n_ts"]
df_der_p_ts = data["der_p_ts"]
df_storage_emax_ts = data["storage_emax_ts"]
df_storage_lmax_ts = data["storage_lmax_ts"]
df_storage_n_ts = data["storage_n_ts"]
df_storage_pmax_ts = data["storage_pmax_ts"]
df_line_fwcap_ts = data["line_fwcap_ts"]
df_line_rvcap_ts = data["line_rvcap_ts"]

# NOTE:
# Sienna doesn't support change of emax and lmax, we need to add that as extra constraints straight to JuMP data
# Sienna also doesn't support change of n, that is number of available unit
# When we add constraints to JuMP model, check first is the timeseries data changes or not

# ================================
# DEBUG SECTION
# ================================

# Configuration for debugging n
df_static = df_generator
id_col = "id_gen"
col_ref = "n"
df_ts = df_generator_n_ts
target_datetime = DateTime("2024-02-01T00:00:00")
columns_to_check = ["date", "1", "84", "69"]
date_start = DateTime(2024, 1, 1)
date_end = DateTime(2025, 1, 1)

# # Configuration for debugging pmax
# df_static = df_generator
# id_col = "id_gen"
# col_ref = "pmax"
# df_ts = df_generator_pmax_ts
# target_datetime = DateTime("2044-06-30T00:00:00")
# columns_to_check = ["date", "78", "79"]
# date_start = DateTime(2044, 6, 28)
# date_end = DateTime(2044, 7, 2)

# Scenario
scenario = 1
interval = Dates.Hour(1)

# Create time series
df_ts_full = get_full_ts_df(
    df_static, df_ts, id_col, col_ref, scenario, date_start, date_end, interval,
)

# Calculate the datetime range for display
window_hours = 48
start_datetime_show = target_datetime - Hour(window_hours)
end_datetime_show = target_datetime + Hour(window_hours)
date_filter_show = (
    (df_ts_full.date .>= start_datetime_show) .& (df_ts_full.date .<= end_datetime_show)
)

println("\nTime series output (around target datetime):")
show(df_ts_full[date_filter_show, columns_to_check], allrows=true)
