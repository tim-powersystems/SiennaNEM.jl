# Accumulate all results from the loop
# NOTE:
#   Bug in time_index for:
# 
#       StorageEnergySurplusVariable__EnergyReservoirStorage
#       StorageEnergyShortageVariable__EnergyReservoirStorage
# 
# See: https://github.com/NREL-Sienna/StorageSystemsSimulations.jl/issues/77
results = decision_problem_results  # used for eda
dfs_res = SiennaNEM.get_results_dataframes(decision_problem_results)

# Export to CSV
SiennaNEM.export_optimization_results_to_csv(
    dfs_res, 
    "examples/result/nem12/csv/$(schedule_name)/scenario-$(scenario)"; 
    prefix="$(schedule_name)_scenario-$(scenario)"
)

## To Export to PRASNEM wide format:
# dfs_res_wide = Dict{String, Dict{String, Any}}()
# for key in keys(dfs_res["realized"])
#     dfs_res_wide[key] = Dict{String, Any}()
#     for key_ in keys(dfs_res["realized"][key])
#         dfs_res_wide[key][key_] = SiennaNEM.long_to_wide(dfs_res["realized"][key][key_])
#     end
# end
