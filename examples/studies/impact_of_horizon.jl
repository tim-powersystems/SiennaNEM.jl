using SiennaNEM
using Dates

using PowerSimulations
using PowerSystems

using HiGHS

# setup optimizer
optimizer = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01)
template_uc = SiennaNEM.build_problem_base_uc()

nem_reliability_data_dir = joinpath(@__DIR__, "../../..", "NEM-reliability-suite")
pisp_data_dir = joinpath(nem_reliability_data_dir, "data/pisp-datasets/out-ref4006-poe10")
arrow_dir = joinpath(pisp_data_dir, "arrow")
system_data_dir = arrow_dir
schedule_names = filter(
    name -> startswith(name, "schedule-"),
    readdir(arrow_dir)
)
schedule_name = schedule_names[1]

ts_data_dir = joinpath(system_data_dir, schedule_name)
scenario = 1
interval = Hour(24)

data = SiennaNEM.get_data(system_data_dir, ts_data_dir)
sys = SiennaNEM.create_system!(data)

initial_day = first(data["generator_pmax_tsf"][:, :date])
target_day = initial_day + Day(1)
results = Dict{String, Any}()

# 24 Hours, single window
horizon = Hour(24)
initial_time = target_day
sys = SiennaNEM.create_system!(data)
SiennaNEM.add_ts!(
    sys, data;
    horizon=horizon,
    interval=interval,
    scenario=scenario,
)
decision_model = SiennaNEM.run_decision_model(
    template_uc, sys;
    horizon=horizon,
    initial_time=initial_time,
    optimizer=optimizer,
)
results[string(horizon.value)] = OptimizationProblemResults(decision_model)

# 48 Hours, single window, including Day-1
horizon = Hour(48)
initial_time = target_day - Day(1)
sys = SiennaNEM.create_system!(data)
SiennaNEM.add_ts!(
    sys, data;
    horizon=horizon,
    interval=interval,
    scenario=scenario,
)
decision_model = SiennaNEM.run_decision_model(
    template_uc, sys;
    horizon=horizon,
    initial_time=initial_time,
    optimizer=optimizer,
)
results[string(horizon.value) * "_prev"] = OptimizationProblemResults(decision_model)

# # 48 Hours, single window, including Day+1
# horizon = Hour(48)
# initial_time = target_day
# sys = SiennaNEM.create_system!(data)
# SiennaNEM.add_ts!(
#     sys, data;
#     horizon=horizon,
#     interval=interval,
#     scenario=scenario,
# )
# decision_model = SiennaNEM.run_decision_model(
#     template_uc, sys;
#     horizon=horizon,
#     initial_time=initial_time,
#     optimizer=optimizer,
# )
# results[string(horizon.value) * "_next"] = OptimizationProblemResults(decision_model)

# # 72 Hours, single window, including Day-1 and Day+1
# horizon = Hour(72)
# initial_time = target_day - Day(1)
# sys = SiennaNEM.create_system!(data)
# SiennaNEM.add_ts!(
#     sys, data;
#     horizon=horizon,
#     interval=interval,
#     scenario=scenario,
# )
# decision_model = SiennaNEM.run_decision_model(
#     template_uc, sys;
#     horizon=horizon,
#     initial_time=initial_time,
#     optimizer=optimizer,
# )
# results[string(horizon.value)] = OptimizationProblemResults(decision_model)

# # 72 Hours, two windows rolling horizon, including Day-1, Day+1, Day+2
# horizon = Hour(72)
# simulation_steps = 2
# problem_name = "UC"
# initial_time = target_day - Day(1)
# sys = SiennaNEM.create_system!(data)
# SiennaNEM.add_ts!(
#     sys, data;
#     horizon=horizon,
#     interval=interval,
#     scenario=scenario,
# )
# simulation = SiennaNEM.run_simulation(
#     template_uc, sys;
#     simulation_folder="examples/result/studies/impact_of_horizon",
#     simulation_name="$(schedule_name)_scenario-$(scenario)",
#     simulation_steps=simulation_steps,
#     decision_model_kwargs=(
#         optimizer=optimizer,
#         name=problem_name,
#     ),
# )
# results[string(horizon.value) * "_rolling"] = get_decision_problem_results(
#     SimulationResults(simulation), problem_name
# )
