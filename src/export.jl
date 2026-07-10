using PowerSimulations

"""
    export_optimization_results_to_csv(
        dfs_res::Any,
        output_dir::String;
        prefix::String=""
    )

Export accumulated optimization results to CSV files.

# Arguments
- `dfs_res`: Dictionary of results from `accumulate_optimization_results`
- `output_dir`: Directory path for CSV files (will be created if it doesn't exist)
- `prefix`: Optional prefix for filenames (default: "")

# Returns
- `Int`: Number of files exported
"""
function export_optimization_results_to_csv(
    dfs_res::Any,
    output_dir::String;
    prefix::String=""
)
    mkpath(output_dir)
    
    for (category, dfs) in dfs_res
        for (name, data) in dfs
            if data isa AbstractDict
                # handle nested rolling horizon: iterate over each step
                for (step, (_, df)) in enumerate(data)
                    filename = if isempty(prefix)
                        "$(category)_$(name)_$(step).csv"
                    else
                        "$(prefix)_$(category)_$(name)_$(step).csv"
                    end
                    filepath = joinpath(output_dir, filename)
                    CSV.write(filepath, df)
                end
            else
                # handle non-nested data (single DataFrame)
                filename = if isempty(prefix)
                    "$(category)_$(name).csv"
                else
                    "$(prefix)_$(category)_$(name).csv"
                end
                filepath = joinpath(output_dir, filename)
                CSV.write(filepath, data)
            end
        end
    end
    
    println("Successfully exported file(s) to: $output_dir/*.csv")
end

"""
    get_results_dataframes(results::Union{PowerSimulations.SimulationProblemResults, PowerSimulations.OptimizationProblemResults})

Extract optimization results from a single OptimizationProblemResults or
SimulationProblemResults into organized DataFrames.

Uses `optimization_result_handlers` constant to automatically extract all result categories
(expression, variable, parameter, aux_variable, dual).

# Arguments
- `results`: Single optimization problem results.

# Returns
- `Dict{String, Dict{String, Any}}`: Nested dictionary where:
  - First level keys are result categories (expression, variable, parameter, aux_variable, dual)
  - Second level keys are specific result names
  - Values are DataFrames for each result
"""
function get_results_dataframes(results::Union{PowerSimulations.SimulationProblemResults, PowerSimulations.OptimizationProblemResults})
    dfs = Dict(
        "expression" => read_expressions(results),
        "aux_variable" => read_aux_variables(results),
        "parameter" => read_parameters(results),
        "variable" => read_variables(results),
        "dual" => read_duals(results),
    )
    if results isa PowerSimulations.SimulationProblemResults
        dfs["realized"] = Dict(
            "expression" => read_realized_expressions(results),
            "aux_variable" => read_realized_aux_variables(results),
            "parameter" => read_realized_parameters(results),
            "variable" => read_realized_variables(results),
            "dual" => read_realized_duals(results),
        )
    end
    return dfs
end

"""
    get_results_dataframes(results_dict::Dict{DateTime, OptimizationProblemResults})

Extract and accumulate optimization results from multiple time slices into organized DataFrames.

Uses `optimization_result_handlers` constant to automatically extract all result categories
(expression, variable, parameter, aux_variable, dual) from each time slice and concatenate them.

# Arguments
- `results_dict::Dict{DateTime, OptimizationProblemResults}`: Dictionary mapping time slices
  to their optimization results.

# Returns
- `Dict{String, Dict{String, DataFrame}}`: Nested dictionary where:
  - First level keys are result categories (expression, variable, parameter, aux_variable, dual)
  - Second level keys are specific result names
  - Values are concatenated DataFrames from all time slices
"""
function get_results_dataframes(results_dict::Dict{DateTime, OptimizationProblemResults})
    # Initialize results dictionary from handlers
    dfs_res = Dict{String, DataFrame}()
    
    # Accumulate all results
    # TODO: sort by DateTime keys for overlap and remove duplicates, keep last
    for res in values(results_dict)
        for (category, list_fn, read_fn) in optimization_result_handlers
            for item in list_fn(res)
                df = sort_res_cols(read_fn(res, item))
                
                # Append or initialize DataFrame
                if haskey(dfs_res[category], item)
                    dfs_res[category][item] = vcat(dfs_res[category][item], df)
                else
                    dfs_res[category][item] = df
                end
            end
        end
    end
    
    return dfs_res
end
