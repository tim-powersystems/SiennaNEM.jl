# TODO: request new format for "schedule-1w"
# nem_reliability_data_dir = joinpath(@__DIR__, "../..", "NEM-reliability-suite")
# include("test_run_simulation.jl")
# @testset "NEM reliability data - CSV" verbose = true begin
#     if isdir(nem_reliability_data_dir)
#         _, _, _ = test_run_simulation(
#             joinpath(nem_reliability_data_dir, "data", "csv"),
#             joinpath(nem_reliability_data_dir, "data", "csv", "schedule-1w"),
#             "csv",
#         )
#     else
#         @test_skip "NEM reliability data directory not found"
#     end
# end
