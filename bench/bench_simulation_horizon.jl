using Dates
using TimeSeries
using InfrastructureSystems
using PowerSystems
using PowerSimulations
using StorageSystemsSimulations
using HiGHS
using SiennaNEM

const IS = InfrastructureSystems

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
    verbose::Bool=true,
)
    # NOTE:
    #   There is a bug/bottle neck in this code that make running small number
    # of steps with small windows, took hours in large time series data set.
    # The length of the original time series data should not impact both build
    # and execution.

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

    timings = Dict{String, Float64}()

    timings["DecisionModel"] = @elapsed begin
        # Create decision model with the provided template
        decision_model = DecisionModel(
            template, sys;
            decision_model_kwargs...
        )
    end

    timings["SimulationModels"] = @elapsed begin
        # Create simulation models container
        sim_models = SimulationModels(
            decision_models=[decision_model]
        )
    end

    timings["SimulationSequence"] =  @elapsed begin
        # Automatic initial condition propagation with InterProblemChronology
        sequence = SimulationSequence(
            models=sim_models,
            ini_cond_chronology=InterProblemChronology(),
        )
    end

    timings["Simulation"] = @elapsed begin
        # Create and build simulation
        sim = Simulation(;
            models=sim_models,
            sequence=sequence,
            name=simulation_name,
            simulation_folder=simulation_folder,
            steps=simulation_steps,
            simulation_kwargs...
        )
    end

    timings["build!"] = @elapsed begin
        build!(sim)
    end

    timings["execute!"] = @elapsed begin
        execute!(sim)
    end

    if verbose
        println("\n  Timings:")
        for (step, time) in sort(collect(timings), by=x->x[2], rev=true)
            println("    $(rpad(step, 20)): $(round(time, digits=2))s")
        end
    end

    return sim, timings
end

scenario = 1
horizon = Hour(72)
interval = Hour(24)
simulation_steps = 2
template_uc = SiennaNEM.build_problem_base_uc()
optimizer = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01)
results = []
syss = Dict{Int, System}()

reference_trace = 4006
poe = 10
tyear = 2025
file_format = "arrow"
system_data_dir = joinpath(@__DIR__, "../..", "NEM-reliability-suite", "data", "pisp-datasets", "out-ref$reference_trace-poe$poe", file_format)
ts_data_dir = joinpath(system_data_dir, "schedule-$tyear")
data = SiennaNEM.get_data(system_data_dir, ts_data_dir)
sys = SiennaNEM.create_system!(data)
SiennaNEM.add_ts!(
    sys, data;
    horizon=horizon,  # horizon of each time slice that will be used in the study
    interval=interval,  # interval within each time slice, not the resolution of the time series
    scenario=scenario,  # scenario number
)

total_ts_length = IS.get_forecast_window_count(sys.data) * horizon
total_time = @elapsed begin
    _, timings = run_simulation(
        template_uc, sys;
        simulation_steps=simulation_steps,
        decision_model_kwargs=(optimizer=optimizer,),
        verbose=true,
    )
end
println("    $(rpad("TOTAL", 20)): $(round(total_time, digits=2))s")
push!(results, (n=total_ts_length, total_time=total_time, timings=timings))
syss[total_ts_length.value] = sys

# Timings:
# execute!            : 148.04s
# build!              : 1.77s
# DecisionModel       : 0.0s
# SimulationSequence  : 0.0s
# SimulationModels    : 0.0s
# Simulation          : 0.0s
# TOTAL               : 149.94s

# Summary report
println("\n" * "=" ^ 70)
println("PERFORMANCE SUMMARY - Bug Demonstration")
println("=" ^ 70)
println(rpad("Repetitions", 15), rpad("Total Time", 15), "Scaling Factor")
println("-" ^ 70)

baseline = results[1].total_time
for result in results
    scaling = result.total_time / baseline
    println(
        rpad("$(result.n)", 15),
        rpad("$(round(result.total_time, digits=2))s", 15),
        "$(round(scaling, digits=2))x"
    )
end
