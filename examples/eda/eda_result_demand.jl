## Demand Post Processing
timecol = :DateTime
if !haskey(dfs_res, "post")
    dfs_res["post"] = Dict{String,Any}()
end
if !haskey(dfs_res, "map")
    add_maps!(data)
end

if results isa PowerSimulations.SimulationProblemResults
    dfs_res_post = SiennaNEM.postprocess_demand_power(dfs_res["realized"], data["map"])
elseif results isa PowerSimulations.OptimizationProblemResults
    dfs_res_post = SiennaNEM.postprocess_demand_power(dfs_res, data["map"])
end
