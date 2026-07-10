using Dates
using PowerSystems
using PowerSimulations


"""
    run_simulation(
        template::ProblemTemplate,
        sys::System;
        simulation_name::Union{String, Nothing}=nothing,
        simulation_folder::Union{String, Nothing}=nothing,
        simulation_steps::Union{Int, Nothing}=nothing,
        decision_model_kwargs::NamedTuple=(;),
        simulation_kwargs::NamedTuple=(;),
    )

Set up and solve multiple unit commitment decision models in a sequential simulation
across forecast time windows with automatic initial condition propagation.

This function creates a `Simulation` using PowerSimulations' `SimulationSequence` with
`InterProblemChronology()` to automatically propagate initial conditions (generator
status, power levels, MUT/MDT counters, storage SoC) between consecutive time windows.

# Arguments
- `template::ProblemTemplate`: The decision model template defining the UC formulation.
- `sys::System`: The PowerSystems system object containing the network and time series
    data. Must be pre-built with time series using `add_ts!` with desired `horizon` and
    `interval`.

# Keyword Arguments
- `simulation_name::Union{String, Nothing}=nothing`: Name for the simulation. Defaults
    to "DA-UC".
- `simulation_folder::Union{String, Nothing}=nothing`: Directory for simulation output.
    Creates a temporary directory if `nothing`.
- `simulation_steps::Union{Int, Nothing}=nothing`: Number of forecast windows to solve.
    If `nothing`, runs for all forecast windows in the system.
- `decision_model_kwargs::NamedTuple=(;)`: Keyword arguments for `DecisionModel`
    constructor (e.g., `optimizer`, `warm_start`, etc.)
- `simulation_kwargs::NamedTuple=(;)`: Additional keyword arguments for `Simulation`
    constructor.

# Returns
- `Simulation`: The built and executed simulation object containing results for all time
    windows.

# Notes
- Initial conditions are automatically propagated between windows via
    `InterProblemChronology()`.
- Storage state of charge carries over between consecutive windows.
- Generator status, power levels, and MUT/MDT counters are maintained across the
    sequence.

# See Also
- `run_decision_model()` for single-window optimization
- `run_decision_models()` for independent windows without chronology
"""
function run_simulation(
    template::ProblemTemplate,
    sys::System;
    simulation_name::Union{String,Nothing}=nothing,
    simulation_folder::Union{String,Nothing}=nothing,
    simulation_steps::Union{Int,Nothing}=nothing,
    decision_model_kwargs::NamedTuple=(;),
    simulation_kwargs::NamedTuple=(;),
)
    # TODO: Improve execution! speed

    if simulation_name === nothing
        simulation_name = "DA-UC"
    end

    if simulation_folder === nothing
        simulation_folder = mktempdir()
    else
        mkpath(simulation_folder)
    end

    if simulation_steps === nothing
        simulation_steps = IS.get_forecast_window_count(sys.data)
    end

    # Create decision model with the provided template
    decision_model = DecisionModel(
        template, sys;
        decision_model_kwargs...
    )

    # Create simulation models container
    sim_models = SimulationModels(
        decision_models=[decision_model]
    )

    # Automatic initial condition propagation with InterProblemChronology
    sequence = SimulationSequence(
        models=sim_models,
        ini_cond_chronology=InterProblemChronology(),
    )

    # Create and build simulation
    sim = Simulation(;
        models=sim_models,
        sequence=sequence,
        name=simulation_name,
        simulation_folder=simulation_folder,
        steps=simulation_steps,
        simulation_kwargs...
    )

    build!(sim)
    execute!(sim)

    return sim
end


"""
    run_decision_models(
        template::ProblemTemplate,
        sys::System;
        simulation_steps::Union{Int, Nothing}=nothing,
        decision_model_kwargs::NamedTuple=(;),
    )

Solve unit commitment decision models in a manual loop, once per forecast window,
without initial condition propagation.

This function iterates over forecast initial times and constructs and solves a separate
`DecisionModel` for each window. Initial conditions are NOT propagated between windows;
each problem is solved independently with default initial conditions.

# Arguments
- `template::ProblemTemplate`: The decision model template defining the UC formulation.
- `sys::System`: The PowerSystems system object with time series data.

# Keyword Arguments
- `simulation_steps::Union{Int, Nothing}=nothing`: Number of windows to solve.
    If `nothing`, all forecast windows are processed.
- `decision_model_kwargs::NamedTuple=(;)`: Keyword arguments forwarded to
    `DecisionModel` (e.g., `optimizer`, `warm_start`).

# Returns
- `OrderedDict{DateTime, DecisionModel}`: Dictionary mapping each forecast initial time
    to its solved `DecisionModel`.

# Notes
- Each time window is solved independently without chronology.
- Storage state of charge does NOT carry over between windows.
- Generator status, power levels, and MUT/MDT counters reset each window.
- For proper multi-period optimization with chronology, use `run_simulation()` instead.

# See Also
- `run_simulation()` for sequential simulation with initial condition propagation
- `run_decision_model()` for single-window optimization
"""
function run_decision_models(
    template::ProblemTemplate,
    sys::System;
    simulation_steps::Union{Int,Nothing}=nothing,
    decision_model_kwargs::NamedTuple=(;),
)
    decision_models = OrderedDict{DateTime,DecisionModel}()
    for (step, initial_time_slice) in enumerate(
        InfrastructureSystems.get_forecast_initial_times(sys.data)
    )
        # Create and solve the decision model with the current time slice
        decision_model = DecisionModel(
            template, sys;
            horizon=InfrastructureSystems.get_forecast_horizon(sys.data),
            initial_time=initial_time_slice,
            decision_model_kwargs...
        )

        build!(decision_model; output_dir=mktempdir())
        solve!(decision_model)
        decision_models[initial_time_slice] = decision_model

        # Break if we've reached the desired number of simulation steps
        if step >= simulation_steps
            break
        end
    end
    return decision_models
end


"""
    run_decision_model(
        template::ProblemTemplate,
        sys::System;
        kwargs...
    )

Set up and solve a single unit commitment decision model for one time window.

# Arguments
- `template::ProblemTemplate`: The decision model template defining the UC formulation.
- `sys::System`: The PowerSystems system object containing the network and time series
    data.

# Keyword Arguments
- `kwargs...`: Additional keyword arguments to pass to `DecisionModel` constructor
    (e.g., `optimizer`, `horizon`, `initial_time`, `warm_start`, etc.)

# Returns
- `DecisionModel`: The solved decision model object.

# Notes
- The system must be pre-built with time series data.
- If `initial_time` is specified, it must align with the time series data timestamps.
- A temporary directory is created for decision model output.

# See Also
- `run_decision_models()` for solving multiple independent windows
- `run_simulation()` for sequential simulation with chronology
"""
function run_decision_model(
    template::ProblemTemplate,
    sys::System;
    kwargs...
)
    # Create and solve the decision model
    decision_model = DecisionModel(
        template, sys;
        kwargs...
    )

    build!(decision_model; output_dir=mktempdir())
    solve!(decision_model)

    return decision_model
end


"""
    get_result(decision_model::DecisionModel)

Extract optimization results from a solved decision model.

# Arguments
- `decision_model::DecisionModel`: A solved decision model.

# Returns
- `OptimizationProblemResults`: The optimization results containing objective value,
    variable values, dual values, and other solution information.
"""
function get_result(decision_model::DecisionModel)
    return OptimizationProblemResults(decision_model)
end


"""
    get_results(decision_models::OrderedDict)

Extract optimization results from multiple solved decision models.

# Arguments
- `decision_models::OrderedDict`: Dictionary mapping forecast initial times to solved
    `DecisionModel` objects, as returned by `run_decision_models()`.

# Returns
- `OrderedDict{DateTime, OptimizationProblemResults}`: Dictionary mapping each forecast
    initial time to its corresponding optimization results.
"""
function get_results(decision_models::OrderedDict)
    results = OrderedDict{DateTime,OptimizationProblemResults}()
    for (initial_time, decision_model) in decision_models
        results[initial_time] = OptimizationProblemResults(decision_model)
    end
    return results
end
