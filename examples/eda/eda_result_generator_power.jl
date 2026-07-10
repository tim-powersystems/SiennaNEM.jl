## Generator Post Processing
# Create mapping from bus ID to component columns
# NOTE: currently, the Hydro is included as ThermalStandard

timecol = :DateTime
if !haskey(dfs_res, "post")
    dfs_res["post"] = Dict{String,Any}()
end
if !haskey(dfs_res, "map")
    add_maps!(data)
end

if results isa PowerSimulations.SimulationProblemResults
    dfs_res_post = SiennaNEM.postprocess_generator_power(dfs_res["realized"], data["map"])
elseif results isa PowerSimulations.OptimizationProblemResults
    dfs_res_post = SiennaNEM.postprocess_generator_power(dfs_res, data["map"])
end

if haskey(dfs_res, "post")
    merge!(dfs_res["post"], dfs_res_post)
else
    dfs_res["post"] = dfs_res_post
end
