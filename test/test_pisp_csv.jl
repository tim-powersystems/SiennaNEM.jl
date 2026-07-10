nem_reliability_data_dir = joinpath(@__DIR__, "../..", "NEM-reliability-suite")
pisp_data_dir = joinpath(nem_reliability_data_dir, "data/pisp-datasets/out-ref4006-poe10")
include("test_run_simulation.jl")
@testset "PISP data - CSV" verbose = true begin
    if isdir(pisp_data_dir)
        csv_dir = joinpath(pisp_data_dir, "csv")
        if isdir(csv_dir)
            schedule_names = filter(
                name -> startswith(name, "schedule-"),
                readdir(csv_dir)
            )
            if !isempty(schedule_names)
                _, _, _ = test_run_simulation(
                    csv_dir,
                    joinpath(csv_dir, schedule_names[1]),
                    "csv",
                )
            else
                @test_skip "No schedule directories found in PISP CSV data"
            end
        else
            @test_skip "PISP CSV data directory not found"
        end
    else
        @test_skip "PISP data directory not found"
    end
end
