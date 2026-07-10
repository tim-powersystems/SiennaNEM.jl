using Test
using SiennaNEM

@testset "SiennaNEM Tests" verbose=true begin
    include("test_nem_reliability_csv.jl")
    include("test_nem_reliability_arrow.jl")
    # include("test_pisp_arrow.jl")
    # include("test_pisp_csv.jl")
    include("test_forward_fill.jl")
end
