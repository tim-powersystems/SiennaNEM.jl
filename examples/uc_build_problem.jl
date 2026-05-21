using SiennaNEM
using Dates

using PowerSimulations

using HiGHS

# setup optimizer
optimizer = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01)

# NOTE:
#   The `horizon = Hour(T)` parameter defines the optimization window span of T
# hours for each decision model. The `interval = Hour(I)` parameter defines the
# sliding window shift of I hours between consecutive time slices, starting from
# the minimum date in `minimum(data["demand_l_ts"][!, :date])`.
#
#   For example, with horizon=48 and interval=24:
#   - Window 1: Hours 0-47
#   - Window 2: Hours 24-71 (overlaps 24 hours with Window 1)
#   - Window 3: Hours 48-95, etc.
#
#   When interval < horizon, windows overlap. When interval = horizon, windows
# are sequential without overlap. When interval > horizon, there will be gaps
# between windows.
#
#   Trade-offs:
#   - Larger horizon: Longer optimization windows, better long-term decisions.
#   - Smaller interval: More frequent re-optimization and overlapping solutions,
#     but have more flexibility in selecting time slices that will be used, 
#
#   Note: In `run_simulation`, the full `horizon` is always used for each
# optimization window.

reference_trace = 4006
poe = 10
tyear = 2025
file_format = "arrow"
system_data_dir = joinpath(
    @__DIR__, "../..", "NEM-reliability-suite", "data", "pisp-datasets",
    "out-ref$reference_trace-poe$poe", file_format
)
schedule_name = "schedule-$tyear"
ts_data_dir = joinpath(system_data_dir, schedule_name)

scenario = 1
horizon = Hour(12)
interval = Hour(6)

# data and system
data = SiennaNEM.get_data(system_data_dir, ts_data_dir)
sys = SiennaNEM.create_system!(data)
SiennaNEM.add_ts!(
    sys, data;
    horizon=horizon,  # horizon of each time slice that will be used in the study
    interval=interval,  # interval within each time slice, not the resolution of the time series
    scenario=scenario,  # scenario number
)

# problem template
template_uc = SiennaNEM.build_problem_base_uc()
