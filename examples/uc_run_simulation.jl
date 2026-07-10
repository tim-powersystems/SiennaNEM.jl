# NOTE:
#   This function accept additional keyword arguments to pass to `DecisionModel`]
# constructor.
simulation_steps = 2
problem_name = "UC"
simulation_name = "ref$reference_trace-poe$poe-tyear$tyear-s$scenario"
simulation = SiennaNEM.run_simulation(
    template_uc, sys;
    simulation_folder="examples/result/simulation_folder",
    simulation_name=simulation_name,
    simulation_steps=simulation_steps,
    decision_model_kwargs=(
        optimizer=optimizer,
        name=problem_name,
    ),
)
simulation_results = SimulationResults(simulation)
decision_problem_results = get_decision_problem_results(
    simulation_results, problem_name
)
