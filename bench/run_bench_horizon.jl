using SiennaNEM
using CSV
using DataFrames
using Dates
using Plots
using Printf

include("bench_horizon.jl")

# --- Input paths ---
const DF = DataFrames

reference_trace = 4006
poe = 10
tyear = 2025
file_format = "arrow"
const DATA_DIR = joinpath(@__DIR__, "../..", "NEM-reliability-suite", "data", "pisp-datasets", "out-ref$reference_trace-poe$poe", file_format)
const TS_DIR = joinpath(system_data_dir, "schedule-$tyear")

# --- Run benchmarks ---
println("Running horizon benchmarks...")
results = bench_horizon_all(
    DATA_DIR, TS_DIR;
    horizons=[Hour(6), Hour(12), Hour(24), Hour(48), Hour(96)],
    samples=5, seconds=5
)

# --- Build detailed statistics table ---
df_stats = DataFrame(
    horizon_hour=Int[],
    operation=String[],
    n_samples=Int[],
    min_ms=Float64[],
    median_ms=Float64[],
    max_ms=Float64[],
    std_ms=Float64[]
)

for (h_hrs, group) in results
    for op in ["model", "build", "solve"]
        trial = group[op]
        n_samples = length(trial.times)
        times_ms = trial.times ./ 1_000_000  # Convert to ms
        
        push!(df_stats, (
            h_hrs,
            op,
            n_samples,
            round(minimum(times_ms), digits=2),
            round(median(times_ms), digits=2),
            round(maximum(times_ms), digits=2),
            round(std(times_ms), digits=2)
        ))
    end
end

# Sort by horizon then operation
sort!(df_stats, [:horizon_hour, :operation])

# Save
output_csv_dir = "bench/csv"
mkpath(output_csv_dir)
filename = "bench_horizon_stats.csv"
filepath = joinpath(output_csv_dir, filename)
CSV.write(filepath, df_stats)

# --- Build df compact table ---
df_compact = DataFrame(
    horizon_hour=Int[],
    operation=String[],
    median_ms=Float64[]
)

for (h_hrs, group) in results
    # Individual operations
    for op in ["model", "build", "solve"]
        time_ms = median(group[op]).time / 1_000_000
        push!(df_compact, (h_hrs, op, round(time_ms, digits=2)))
    end

    # Total = sum of medians
    total_ms = (
        median(group["model"]).time +
        median(group["build"]).time +
        median(group["solve"]).time
    ) / 1_000_000
    push!(df_compact, (h_hrs, "total", round(total_ms, digits=2)))
end

# sort first
sort!(df_compact, :horizon_hour)

df_stage = filter(:operation => op -> op ∈ ["model", "build", "solve", "total"], df_compact)
df_wide = unstack(df_stage, :operation, :median_ms)

df_wide.solve_s = round.(df_wide.solve ./ 1000, digits=2)
df_wide.solve_min = round.(df_wide.solve ./ 60000, digits=2)
df_wide.total_s = round.(df_wide.total ./ 1000, digits=2)
df_wide.total_min = round.(df_wide.total ./ 60000, digits=2)
DF.rename!(df_wide, :model => :model_ms)
DF.rename!(df_wide, :build => :build_ms)
DF.rename!(df_wide, :solve => :solve_ms)
DF.rename!(df_wide, :total => :total_ms)

output_dir = "bench/csv"
mkpath(output_dir)
filename = "bench_horizon_compact.csv"
filepath = joinpath(output_dir, filename)
CSV.write(filepath, df_wide)

# For presentation
# output_dir = "bench/csv"
# filename = "bench_horizon_compact.csv"
# filepath = joinpath(output_dir, filename)
# df_wide = CSV.read(filepath, DataFrame)
DF.rename!(df_wide, :model_ms => "model (ms)")
DF.rename!(df_wide, :build_ms => "build (ms)")
DF.rename!(df_wide, :solve_ms => "solve (ms)")
DF.rename!(df_wide, :solve_s => "solve (s)")
DF.rename!(df_wide, :total_ms => "total (ms)")
DF.rename!(df_wide, :total_s => "total (s)")
DF.rename!(df_wide, :total_min => "total (minute)")
DF.rename!(df_wide, :horizon_hour => "horizon (hour)")
df_wide[!, ["horizon (hour)", "model (ms)", "build (ms)", "solve (s)", "total (s)"]]

using PrettyTables

sub = df_wide[!, ["horizon (hour)", "model (ms)", "build (ms)", "solve (s)", "total (s)"]]
table = hcat(string.(sub[!, "horizon (hour)"]), Matrix(sub[:, 2:end]))

pretty_table(
    sub;
    header = ["horizon (hour)", "model (ms)", "build (ms)", "solve (s)", "total (s)"],
    show_row_number = false
)

# --- Plot the compact results ---
ops = ["model", "build", "solve", "total"]
plots = []

# Create proper x-axis labels from df_wide
horizons = df_wide[!, "horizon (hour)"]
x_positions = 1:length(horizons)

for op in ops
    subdf = filter(:operation => ==(op), df_compact)
    sort!(subdf, :horizon_hour)
    
    # Determine y-axis based on operation
    if op == "model"
        ylabel_text = "Time (ms)"
        yscale_type = :identity
        y_values = subdf.median_ms
    elseif op == "build"
        ylabel_text = "Time (ms)"
        yscale_type = :identity
        y_values = subdf.median_ms
    elseif op == "solve"
        ylabel_text = "Time (s)"
        yscale_type = :log10
        y_values = subdf.median_ms ./ 1000  # Convert to seconds
    else  # total
        ylabel_text = "Time (s)"
        yscale_type = :log10
        y_values = subdf.median_ms ./ 1000  # Convert to seconds
    end
    
    p = plot(x_positions, y_values;
             xlabel="Horizon (hours)", ylabel=ylabel_text,
             title=op, lw=2, marker=:circle,
             xticks=(x_positions, string.(horizons)),
             yscale=yscale_type,
             legend=false)
    push!(plots, p)
end

imgs_dir = "bench/imgs"
mkpath(imgs_dir)

plt = plot(plots..., layout=(2,2), size=(900,600))
display(plt)
savefig(plt, joinpath(imgs_dir, "bench_horizon_2x2.png"))

plt = plot(plots..., 
    layout=(1,4), 
    size=(1600, 400),
    left_margin=7.5Plots.mm,
    bottom_margin=7.55Plots.mm,
    top_margin=5Plots.mm,
    right_margin=0Plots.mm
)
display(plt)
savefig(plt, joinpath(imgs_dir, "bench_horizon_1x4.png"))
