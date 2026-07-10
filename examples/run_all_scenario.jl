using SiennaNEM
using PowerSimulations
using HiGHS
using Dates

# Setup optimizer
optimizer = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01)

# Configuration
system_data_dir = "data/nem12/arrow"
years = 2025:2035
scenarios = 1:3
horizon = Hour(24)
interval = Hour(1)
schedule_horizon = Hour(24)
window_shift = Hour(24)

# Create base output directory
base_output_dir = "examples/result/nem12"

println("="^80)
println("Starting multi-scenario, multi-year UC analysis")
println("Scenarios: $(first(scenarios)) - $(last(scenarios))")
println("Years: $(first(years)) - $(last(years))")
println("="^80)

# Loop through each scenario first
for scenario in scenarios
    println("\n" * "█"^80)
    println("Processing Scenario: $scenario")
    println("█"^80)

    # Then loop through each year
    for year in years
        schedule_name = "schedule-$(year)"
        ts_data_dir = joinpath(system_data_dir, schedule_name)

        # Check if directory exists
        if !isdir(ts_data_dir)
            @warn "Skipping $schedule_name - directory not found: $ts_data_dir"
            continue
        end

        println("\n" * "▓"^60)
        println("  Year: $year ($schedule_name)")
        println("▓"^60)

        try
            # ============================================================
            # 1. BUILD SYSTEM
            # ============================================================
            println("\n[1/5] Loading data and building system...")
            data = SiennaNEM.get_data(system_data_dir, ts_data_dir)
            sys = SiennaNEM.create_system!(data)
            SiennaNEM.add_ts!(
                sys, data;
                horizon=horizon,
                interval=interval,
                scenario=scenario,
            )
            println("✓ System built successfully")

            # ============================================================
            # 2. BUILD PROBLEM TEMPLATE
            # ============================================================
            println("\n[2/5] Building problem template...")
            template_uc = SiennaNEM.build_problem_base_uc()
            println("✓ Problem template built")

            # ============================================================
            # 3. RUN DECISION MODEL LOOP
            # ============================================================
            println("\n[3/5] Running decision model loop...")
            res_dict = SiennaNEM.run_simulation(
                template_uc, sys;
                schedule_horizon=schedule_horizon,
                window_shift=window_shift,
                optimizer=optimizer,
                verbose=true,
            )
            println("✓ Decision model loop completed")

            # ============================================================
            # 4. EXTRACT AND EXPORT RESULTS
            # ============================================================
            println("\n[4/5] Extracting optimization results...")
            dfs_res = SiennaNEM.get_results_dataframes(res_dict)

            # Create output directories with scenario-{n}/schedule-{year} structure
            output_prefix = "$(schedule_name)_scenario-$(scenario)"
            csv_dir = joinpath(base_output_dir, "csv", schedule_name, "scenario-$(scenario)")
            # plots_dir = joinpath(base_output_dir, "plots", schedule_name, "scenario-$(scenario)")

            println("\n[5/5] Exporting results...")

            # Export CSV files
            println("\n  → Exporting CSV files...")
            SiennaNEM.export_optimization_results_to_csv(
                dfs_res,
                csv_dir;
                prefix=output_prefix
            )

            println("\n✓ Successfully completed: $scenario, $schedule_name")

        catch e
            @error "Failed to process $scenario, $schedule_name" exception = (e, catch_backtrace())
            continue
        end
    end
end

println("\n" * "="^80)
println("Multi-scenario, multi-year analysis completed!")
println("="^80)

# Generate summary report
println("\nGenerating summary report...")
summary_file = joinpath(base_output_dir, "analysis_summary.txt")
open(summary_file, "w") do io
    println(io, "Multi-Scenario Multi-Year UC Analysis Summary")
    println(io, "="^60)
    println(io, "Scenarios analyzed: scenario-$(first(scenarios)) to scenario-$(last(scenarios))")
    println(io, "Years per scenario: schedule-$(first(years)) to schedule-$(last(years))")
    println(io, "Total runs: $(length(scenarios) * length(years))")
    println(io, "\nConfiguration:")
    println(io, "  Horizon: $horizon")
    println(io, "  Schedule horizon: $schedule_horizon")
    println(io, "  Window shift: $window_shift")
    println(io, "\nOutput structure: scenario-{n}/schedule-{year}")
    println(io, "  CSV: $base_output_dir/csv/scenario-{n}/schedule-{year}/")
    println(io, "  Plots: $base_output_dir/plots/scenario-{n}/schedule-{year}/")
    println(io, "\nFile naming: schedule-{year}_scenario-{n}_category_name.ext")
end
println("✓ Summary saved to: $summary_file")
