using BenchmarkTools
using SiennaNEM
using Dates
using PowerSystems
using PowerSimulations
using HydroPowerSimulations
using StorageSystemsSimulations
using HiGHS

"""
    bench_horizon_setup(system_data_dir, ts_data_dir)

Prepare system, template, and optimizer once.
Returns (template_uc, sys, optimizer).
"""
function bench_horizon_setup(system_data_dir::AbstractString, ts_data_dir::AbstractString)
    data = read_system_data(system_data_dir)
    read_ts_data!(data, ts_data_dir)
    add_tsf_data!(data)
    update_system_data_bound!(data)
    clean_ts_data!(data)

    template_uc = SiennaNEM.build_problem_base_uc()
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01)

    sys = create_system!(data)

    add_ts!(sys, data, scenario=1)
    return template_uc, sys, optimizer
end


"""
    bench_model(template_uc, sys, optimizer, horizon; samples=10, seconds=5)

Benchmark creation of a DecisionModel (no build or solve).
"""
function bench_model(template_uc, sys, optimizer, horizon; samples=10, seconds=5)
    bm = @benchmarkable DecisionModel($template_uc, $sys; optimizer=$optimizer, horizon=$horizon) samples=samples seconds=seconds
    return run(bm)
end


"""
    bench_build(problem; samples=10, seconds=5)

Benchmark the `build!` step only (not solve).
Takes a fresh DecisionModel as input.
"""
function bench_build(problem; samples=10, seconds=5)
    bm = @benchmarkable build!($problem; output_dir=mktempdir()) samples=samples seconds=seconds
    return run(bm)
end


"""
    bench_horizon(problem; samples=10, seconds=5)

Benchmark the `solve!` step for a prepared (built) DecisionModel.
"""
function bench_horizon(problem; samples=10, seconds=5)
    bm = @benchmarkable solve!($problem) samples=samples seconds=seconds
    return run(bm)
end


"""
    bench_horizon_all(system_data_dir, ts_data_dir; horizons=[Hour(6), Hour(12), Hour(24)], samples=10, seconds=5)

Run model, build, and solve benchmarks across horizons.
Returns Dict[horizon_hours => Dict("model"=>…, "build"=>…, "solve"=>…)].
"""
function bench_horizon_all(system_data_dir::AbstractString, ts_data_dir::AbstractString;
                           horizons=[Hour(6), Hour(12), Hour(24)],
                           samples=10, seconds=5)

    template_uc, sys, optimizer = bench_horizon_setup(system_data_dir, ts_data_dir)

    results = Dict{Int,Dict{String,Any}}()
    for h in horizons
        hrs = Int(Dates.value(h))
        println("Benchmarking horizon: $h")

        # model
        model_res = bench_model(template_uc, sys, optimizer, h; samples=samples, seconds=seconds)

        # build
        problem = DecisionModel(template_uc, sys; optimizer=optimizer, horizon=h)
        build_res = bench_build(problem; samples=samples, seconds=seconds)

        # solve
        build!(problem; output_dir=mktempdir())
        solve_res = bench_horizon(problem; samples=samples, seconds=seconds)

        results[hrs] = Dict(
            "model" => model_res,
            "build" => build_res,
            "solve" => solve_res,
        )
    end

    return results
end
