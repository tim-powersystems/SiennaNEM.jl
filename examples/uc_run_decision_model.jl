# NOTE:
#   This function accept additional keyword arguments to pass to `DecisionModel`]
# constructor.
problem_name = "UC"
decision_model = SiennaNEM.run_decision_model(
    template_uc, sys;
    horizon=horizon,  # time horizon for the decision model
    initial_time=DateTime("2025-01-08T00:00:00"),  # initial time for the decision model
    optimizer=optimizer,  # optimizer for the decision model
    name=problem_name,
)

optimization_problem_results = OptimizationProblemResults(decision_model)
