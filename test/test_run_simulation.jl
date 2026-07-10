using Test
using Dates
using HiGHS

using PowerSystems
using PowerSimulations
using InfrastructureSystems

using SiennaNEM


function test_run_simulation(system_data_dir::String, ts_data_dir::String, backend::String)
    """
    Helper function to test system creation from data directory.

    Args:
        system_data_dir: Path to system data directory
        ts_data_dir: Path to time series data directory
        backend: Backend type, "arrow" or "csv"
    """
    horizon = Hour(42)
    interval = Hour(24)
    scenario = 1
    simulation_output_folder = "sienna-files"
    simulation_name = "test_run_simulation_$backend"
    simulation_steps = 2  # number of rolling horizon steps

    # Track timings
    timings = Dict{String, Float64}()

    # Read data
    data = nothing
    @testset "[$(backend)] Get data" verbose = true begin
        timings["get_data"] = @elapsed begin
            data = SiennaNEM.get_data(system_data_dir, ts_data_dir; file_format=backend)
            @test data !== nothing
        end
    end

    # Create system
    sys_sienna = nothing
    @testset "[$(backend)] Create system" verbose = true begin
        timings["create_system"] = @elapsed begin
            sys_sienna = SiennaNEM.create_system!(data)
            @test typeof(sys_sienna) <: PowerSystems.System
        end
    end

    # Add time series
    @testset "[$(backend)] Add time series" verbose = true begin
        timings["add_ts"] = @elapsed begin
            SiennaNEM.add_ts!(
                sys_sienna, data;
                horizon=horizon,
                interval=interval,
                scenario=scenario,
            )
            @test InfrastructureSystems.get_forecast_horizon(sys_sienna.data) == horizon
        end
    end

    # Build problem template
    template_uc = nothing
    @testset "[$(backend)] Build problem template" verbose = true begin
        timings["build_template"] = @elapsed begin
            template_uc = SiennaNEM.build_problem_base_uc()
            @test typeof(template_uc) <: PowerSimulations.ProblemTemplate
        end
    end

    # Run decision model loop
    @testset "[$(backend)] Run decision model loop" verbose = true begin
        timings["run_simulation"] = @elapsed begin
            decision_models = SiennaNEM.run_simulation(
                template_uc, sys_sienna;
                simulation_folder=simulation_output_folder,
                simulation_name=simulation_name,
                simulation_steps=simulation_steps,
                decision_model_kwargs=(
                    optimizer=optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01),
                ),
            )
            @test typeof(decision_models) <: PowerSimulations.Simulation
        end
    end

    # Print timing summary
    total_time = sum(values(timings))
    println("\n=== Timing Summary for $(backend) ===")
    for (step, time) in sort(collect(timings), by=x->x[2], rev=true)
        println("  $step: $(round(time, digits=2))s ($(round(100*time/total_time, digits=1))%)")
    end
    println("  TOTAL: $(round(total_time, digits=2))s")
    println("=" ^ 40)

    return data, sys_sienna, timings
end
