# SiennaNEM

[![Build Status](https://github.com/ARPST-UniMelb/SiennaNEM.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ARPST-UniMelb/SiennaNEM.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ARPST-UniMelb/SiennaNEM.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ARPST-UniMelb/SiennaNEM.jl)

[SiennaNEM.jl](https://github.com/ARPST-UniMelb/SiennaNEM.jl) enables operational scheduling studies of the NEM using [Sienna](https://nrel-sienna.github.io/Sienna/) and [JuMP](https://jump.dev/). It constructs unit commitment models from [PISP](https://github.com/ARPST-UniMelb/PISP.jl) data and provides analysis and visualization tools for system operations insights.

## Usage

See minimum working example workflow in `examples/`. Minimum example with [data](#add-data) from [PISP.jl](#add-data) is as follows,

```julia
using SiennaNEM

using PowerSimulations

using Dates
using HiGHS

# input variables parameters
system_data_dir = joinpath(@__DIR__, "../..", "NEM-reliability-suite", "data", "arrow")
schedule_name = "schedule-2030"
scenario = 1

# data and system
data = SiennaNEM.get_data(
    system_data_dir, joinpath(system_data_dir, schedule_name); file_format="arrow",
)
sys = SiennaNEM.create_system!(data)
SiennaNEM.add_ts!(
    sys, data;
    horizon=Hour(24),  # horizon of each time slice
    interval=Hour(24),  # interval between each time slice step in rolling horizon
    scenario=scenario,  # scenario number
)

# simulation
template_uc = SiennaNEM.build_problem_base_uc()
decision_models = SiennaNEM.run_simulation(
    template_uc, sys;
    simulation_folder="examples/result/simulation_folder",
    simulation_name="$(schedule_name)_scenario-$(scenario)",
    simulation_steps=2,
    decision_model_kwargs=(
        optimizer=optimizer_with_attributes(HiGHS.Optimizer, "mip_rel_gap" => 0.01),
    ),
)
```

## Development

### Installation

<!-- 
NOTE: 
Currently, `InfrastructureSystems = "=3.4.1"` is used in Project.toml due to bug
https://github.com/NREL-Sienna/PowerSimulations.jl/issues/1595
-->

In your Julia global environment (starting Julia with `julia`, no `--project`),

```julia
using Pkg
Pkg.add("Revise")
Pkg.add("TestEnv")
using Revise
```

Activate environment,

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
using Revise
```

Install [`PISP.jl`](https://github.com/ARPST-UniMelb/PISP.jl#),

```julia
using Pkg
Pkg.develop(path="../PISP.jl")
```

### Add data

```julia
using PISP

reference_trace = 4006 
poe = 10 # Probability of exceedance (POE) for demand
target_years = [2030, 2031]

PISP.build_ISP24_datasets(
    downloadpath = joinpath(@__DIR__, "..", "data", "pisp-downloads"),
    poe          = poe,
    reftrace     = reference_trace,
    years        = target_years,
    output_root  = joinpath(@__DIR__, "..", "data", "pisp-datasets"),
    write_csv    = true,
    write_arrow  = true,
    scenarios    = [1,2,3]
    )
```

### Test

> [!NOTE]  
> Tests require the `data/nem12` directory, which is currently not released.

```julia
using Pkg

Pkg.activate(".")
Pkg.resolve()
Pkg.instantiate()
Pkg.precompile()
Pkg.test()
```

### Benchmark

```julia
using Pkg
using TestEnv
TestEnv.activate("SiennaNEM")
Pkg.resolve()
```

run `bench/run_bench_data_format.jl` and `bench/run_bench_horizon.jl`
