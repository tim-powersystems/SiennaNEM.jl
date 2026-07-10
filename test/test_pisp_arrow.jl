nem_reliability_data_dir = joinpath(@__DIR__, "../..", "NEM-reliability-suite")
pisp_data_dir = joinpath(nem_reliability_data_dir, "data/pisp-datasets/out-ref4006-poe10")
include("test_run_simulation.jl")
@testset "PISP data - Arrow" verbose = true begin
    if isdir(pisp_data_dir)
        arrow_dir = joinpath(pisp_data_dir, "arrow")
        if isdir(arrow_dir)
            schedule_names = filter(
                name -> startswith(name, "schedule-"),
                readdir(arrow_dir)
            )
            if !isempty(schedule_names)
                _, _, _ = test_run_simulation(
                    arrow_dir,
                    joinpath(arrow_dir, schedule_names[1]),
                    "arrow",
                )
            else
                @test_skip "No schedule directories found in PISP Arrow data"
            end
        else
            @test_skip "PISP Arrow data directory not found"
        end
    else
        @test_skip "PISP data directory not found"
    end
end
