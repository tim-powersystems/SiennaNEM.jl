# debug ts
using CSV
using DataFrames

include("../src/utils.jl")

data_dir = ts_data_dir
demand_ts_path = joinpath(data_dir, "Demand_load_sched.csv")
generator_ts_path = joinpath(data_dir, "Generator_pmax_sched.csv")
df_demand_ts = CSV.read(demand_ts_path, DataFrame)
df_generator_ts = CSV.read(generator_ts_path, DataFrame)
data["demand_l_ts"] = add_day!(df_demand_ts)
data["generator_pmax_ts"] = add_day!(df_generator_ts)
