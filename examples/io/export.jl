using SiennaNEM

using PowerSystems
using PowerSimulations

using HiGHS
using Dates

reference_trace = 4006
poe = 10
tyear = 2025
file_format = "arrow"
system_data_dir = joinpath(
    @__DIR__, "../..", "NEM-reliability-suite", "data", "pisp-datasets",
    "out-ref$reference_trace-poe$poe", file_format
)
ts_data_dir = joinpath(system_data_dir, "schedule-$tyear")
scenario = 1

data = read_system_data(system_data_dir)
read_ts_data!(data, ts_data_dir)
add_tsf_data!(data; scenario=scenario)
update_system_data_bound!(data)

sys = create_system!(data)
add_ts!(sys, data; scenario=scenario)

to_json(sys, "examples/result/debug/schedule-$tyear.json", force=true)
