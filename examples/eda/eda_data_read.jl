# NOTE:
#   This code is to debug reading data without any pre-processing, unlike what
# SiennaNEM.read_data.get_data.

using Plots, Dates, DataFrames, Arrow

data_files = Dict(
    "bus" => "Bus",
    "demand" => "Demand",
    "der" => "DER",
    "storage" => "ESS",
    "generator" => "Generator",
    "line" => "Line",
)
trace_files = Dict(
    "demand_l_ts" => "Demand_load_sched",
    "generator_pmax_ts" => "Generator_pmax_sched",
    "generator_n_ts" => "Generator_n_sched",
    "der_p_ts" => "DER_pred_sched",
    "storage_emax_ts" => "ESS_emax_sched",
    "storage_lmax_ts" => "ESS_lmax_sched",
    "storage_n_ts" => "ESS_n_sched",
    "storage_pmax_ts" => "ESS_pmax_sched",
    "line_fwcap_ts" => "Line_fwcap_sched",
    "line_rvcap_ts" => "Line_rvcap_sched",
)

nem_reliability_data_dir = joinpath(@__DIR__, "../../..", "NEM-reliability-suite")
pisp_data_dir = joinpath(nem_reliability_data_dir, "data/pisp-datasets/out-ref4006-poe10")
arrow_dir = joinpath(pisp_data_dir, "arrow")
system_data_dir = arrow_dir
# schedule_names = filter(
#     name -> startswith(name, "schedule-"),
#     readdir(arrow_dir)
# )
# schedule_name = schedule_names[1]
schedule_name = "schedule-2038"

ts_data_dir = joinpath(system_data_dir, schedule_name)
scenario = 1
interval = Hour(24)

data = Dict{String,Any}()
for (k, fname) in data_files
    path = joinpath(system_data_dir, fname * ".arrow")
    data[k] = DataFrame(Arrow.Table(path))
end

for (k, fname) in trace_files
    path = joinpath(ts_data_dir, fname * ".arrow")
    data[k] = DataFrame(Arrow.Table(path))
end
