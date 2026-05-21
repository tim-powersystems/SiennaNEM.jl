include("uc_build_problem.jl")
include("uc_run_decision_model.jl")  # for single horizon DecisionModel
include("eda/eda_result_decision_model.jl")  # for single horizon DecisionModel
# include("uc_run_simulation.jl")  # for rolling horizon Simulation
# include("eda/eda_result_simulation.jl")  # for rolling horizon Simulation
# include("eda/eda_result_demand.jl")  # BUG PowerLoad is relocated
include("eda/eda_result_generator_power.jl")
include("eda/eda_result_storage_power.jl")
# include("plot/plot_result_aggregate.jl")  # BUG post processing
