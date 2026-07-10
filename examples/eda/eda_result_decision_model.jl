# Accumulate all results from the loop
results = optimization_problem_results  # used for eda
dfs_res = SiennaNEM.get_results_dataframes(optimization_problem_results)

# Export to CSV
SiennaNEM.export_optimization_results_to_csv(
    dfs_res, 
    "examples/result/nem12/csv/$(schedule_name)/scenario-$(scenario)"; 
    prefix="$(schedule_name)_scenario-$(scenario)"
)

## To Export to PRASNEM wide format:
# dfs_res_wide = Dict{String, Dict{String, Any}}()
# for key in keys(dfs_res)
#     dfs_res_wide[key] = Dict{String, Any}()
#     for key_ in keys(dfs_res[key])
#         dfs_res_wide[key][key_] = SiennaNEM.long_to_wide(dfs_res[key][key_])
#     end
# end
