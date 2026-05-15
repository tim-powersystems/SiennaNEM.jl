## Wind correction factor plot

using Plots
using Plots.PlotMeasures   # needed for `px` and `mm` units

# Parse dates once
windcf_sched[!, :datetime] = DateTime.(windcf_sched[!, :date], "yyyy-mm-dd HH:MM:SS")

id_gen_to_name = get_map_from_df(data["generator"], :id_gen, :name)
gen_ids = unique(windcf_sched[!, :id_gen])

# Filter by date range
dt_start = DateTime("2038-01-23 00:00:00", "yyyy-mm-dd HH:MM:SS")
dt_end   = DateTime("2038-01-25 00:00:00", "yyyy-mm-dd HH:MM:SS")
windcf_filtered = filter(:datetime => d -> dt_start <= d <= dt_end, windcf_sched)

plt = plot(
    xlabel = "Date",
    ylabel = "Correction Factor (p.u.)",
    title  = "Wind Thermal Correction Factor by Location",
    legend = :outertopright,
    size   = (1000, 500),
    left_margin = 5mm,
)

for gid in gen_ids
    sub = filter(:id_gen => ==(gid), windcf_filtered)
    sort!(sub, :datetime)
    plot!(plt, sub[!, :datetime], sub[!, :value]; label = id_gen_to_name[gid])
end

plt

# Parse dates
windcf_sched[!, :datetime] = DateTime.(windcf_sched[!, :date], "yyyy-mm-dd HH:MM:SS")
ta_df[!, :datetime]        = DateTime.(ta_df[!, :date], "yyyy-mm-dd HH:MM:SS")

using PlotlyJS
import PlotlyJS: scatter, Layout, Plot, attr

# --- Data prep ---
scenario_id = 1
windpmax_filtered = filter(:id_gen => idg -> idg in wind_id_gens, data["generator_pmax_ts"])
dt_start = DateTime("2038-01-23 00:00:00", "yyyy-mm-dd HH:MM:SS")
dt_end   = DateTime("2038-01-25 00:00:00", "yyyy-mm-dd HH:MM:SS")
windpmax_filtered = filter(:date => d -> dt_start <= d <= dt_end, windpmax_filtered)

windcf_sched[!, :datetime] = DateTime.(windcf_sched[!, :date], "yyyy-mm-dd HH:MM:SS")
windcf_filtered = filter(:id_gen => idg -> idg in wind_id_gens, windcf_sched)
windcf_filtered = filter(:datetime => d -> dt_start <= d <= dt_end, windcf_filtered)

pm_scen = filter(:scenario => ==(scenario_id), windpmax_filtered)
cf_scen = filter(:scenario => ==(scenario_id), windcf_filtered)

id_gen_to_name = get_map_from_df(data["generator"], :id_gen, :name)
gen_ids = unique(pm_scen[!, :id_gen])
labels  = [id_gen_to_name[gid] for gid in gen_ids]

id_gen_to_capacity = get_map_from_df(data["generator"], :id_gen, :capacity)

# --- Build merged DataFrame ---
merged_all = DataFrame()
for gid in gen_ids
    pm = filter(:id_gen => ==(gid), pm_scen)
    cf = filter(:id_gen => ==(gid), cf_scen)
    merged = innerjoin(pm, cf, on = :date => :datetime, makeunique = true)
    sort!(merged, :date)

    # Retrieve the installed capacity for this generator
    gen_cap = id_gen_to_capacity[gid]

    # This code use:
    # installed_capacity = max(gen.capacity, maximum(trace_value))
    # pmax_corrected = min(cf * installed_capacity, power_output)
    merged[!, :pmax_corrected] = min.(
        merged[!, :value_1] .* gen_cap,  # cf * installed capacity
        merged[!, :value]                # power output
    )

    append!(merged_all, select(merged, :date, :id_gen, :value, :value_1, :pmax_corrected))
end

dates = sort(unique(merged_all[!, :date]))

# --- Build matrices ---
function build_matrix_from(df, val_col)
    hcat([
        begin
            sub = filter(:id_gen => ==(gid), df)
            sort!(sub, :date)
            sub[!, val_col]
        end
        for gid in gen_ids
    ]...)
end

before_gw = build_matrix_from(merged_all, :value)        ./ 1000
after_gw  = build_matrix_from(merged_all, :pmax_corrected) ./ 1000

# --- PlotlyJS stacked area, two subplots ---
colors = [
    "#4e79a7", "#f28e2b", "#e15759", "#76b7b2", "#59a14f",
    "#edc948", "#b07aa1", "#ff9da7", "#9c755f", "#bab0ac",
    "#d37295", "#499894",
]
traces_before = [
    scatter(
        x          = dates,
        y          = before_gw[:, i],
        name       = labels[i],
        stackgroup = "before",
        fill       = "tonexty",
        mode       = "lines",
        legendgroup = labels[i],
        line = attr(color = colors[i])
    )
    for i in 1:length(labels)
]

traces_after = [
    scatter(
        x          = dates,
        y          = after_gw[:, i],
        name       = labels[i],
        stackgroup = "after",
        fill       = "tonexty",
        mode       = "lines",
        legendgroup = labels[i],
        showlegend = false,   # avoid duplicate legend entries
        xaxis      = "x2",
        yaxis      = "y2",
        line = attr(color = colors[i])
    )
    for i in 1:length(labels)
]

layout = Layout(
    title  = "Wind Power — Before vs After CF Correction",
    xaxis  = attr(title = "", domain = [0, 1], anchor = "y"),
    yaxis  = attr(title = "Power Output (GW)", domain = [0.55, 1.0], anchor = "x"),
    xaxis2 = attr(title = "Date", domain = [0, 1], anchor = "y2"),
    yaxis2 = attr(title = "Power Output (GW)", domain = [0.0, 0.45], anchor = "x2"),
    legend = attr(x = 1.02, y = 1.0),
    annotations = [
        attr(text="Before CF Correction", x=0.5, y=1.02, xref="paper", yref="paper", showarrow=false, font=attr(size=13)),
        attr(text="After CF Correction",  x=0.5, y=0.47, xref="paper", yref="paper", showarrow=false, font=attr(size=13)),
    ],
)

Plot([traces_before; traces_after], layout)

id_gen = 120

pm_snsw = filter(:id_gen => ==(id_gen), pm_scen)
cf_snsw = filter(:id_gen => ==(id_gen), cf_scen)

merged = innerjoin(pm_snsw, cf_snsw, on = :date => :datetime, makeunique = true)
sort!(merged, :date)

println(names(merged))  # confirm column names
println(merged[1:5, :]) # sanity check

plt = Plots.plot(
    layout      = (2, 1),
    size        = (1000, 600),
    left_margin = 10mm,
    link        = :x,
)

Plots.plot!(merged[!, :date], merged[!, :value];
    label   = "Before (pmax)",
    ylabel  = "Power (MW)",
    title   = "WIND_SNSW — Before vs After CF",
    subplot = 1,
)

gen_cap = id_gen_to_capacity[id_gen]
Plots.plot!(merged[!, :date], min.(merged[!, :value_1] .* gen_cap, merged[!, :value]);
    label   = "After (min(cf × capacity, pmax))",
    subplot = 1,
)

Plots.plot!(merged[!, :date], merged[!, :value_1];
    label   = "CF",
    ylabel  = "CF (p.u.)",
    title   = "WIND_SNSW — Correction Factor",
    xlabel  = "Date",
    subplot = 2,
    color   = :green,
)

plt
# Conclusion: High ambient temperatures often coincide with periods of low wind output. This is expected, as high ambient temperatures occur from noon to evening, when wind speeds, and consequently wind power output, are typically low.

## Solar
using Plots
using Plots.PlotMeasures   # needed for `px` and `mm` units

# pvmod_roofpv_sched
pvmodcf_roofpv_sched[!, :datetime] = DateTime.(pvmodcf_roofpv_sched[!, :date], "yyyy-mm-dd HH:MM:SS")

id_gen_to_name = get_map_from_df(data["generator"], :id_gen, :name)
gen_ids = unique(pvmodcf_roofpv_sched[!, :id_gen])

# Filter by date range
dt_start = DateTime("2038-01-23 00:00:00", "yyyy-mm-dd HH:MM:SS")
dt_end   = DateTime("2038-01-25 00:00:00", "yyyy-mm-dd HH:MM:SS")
pvmodcf_roofpv_filtered = filter(:datetime => d -> dt_start <= d <= dt_end, pvmodcf_roofpv_sched)

plt = Plots.plot(
    xlabel = "Date",
    ylabel = "Correction Factor (p.u.)",
    title  = "Photovoltaic Thermal Correction Factor by Location",
    legend = :outertopright,
    size   = (1000, 500),
    left_margin = 5mm,
)
for gid in gen_ids
    sub = filter(:id_gen => ==(gid), pvmodcf_roofpv_filtered)
    sort!(sub, :datetime)
    plot!(plt, sub[!, :datetime], sub[!, :value]; label = id_gen_to_name[gid])
end
plt

solar_id_gens = roofpv_id_gens
# --- Data prep ---
scenario_id = 1
solarpmax_filtered = filter(:id_gen => idg -> idg in solar_id_gens, data["generator_pmax_ts"])
dt_start = DateTime("2038-01-23 00:00:00", "yyyy-mm-dd HH:MM:SS")
dt_end   = DateTime("2038-01-25 00:00:00", "yyyy-mm-dd HH:MM:SS")
solarpmax_filtered = filter(:date => d -> dt_start <= d <= dt_end, solarpmax_filtered)

pvmodcf_roofpv_sched[!, :datetime] = DateTime.(pvmodcf_roofpv_sched[!, :date], "yyyy-mm-dd HH:MM:SS")
solarcf_filtered = filter(:id_gen => idg -> idg in solar_id_gens, pvmodcf_roofpv_sched)
solarcf_filtered = filter(:datetime => d -> dt_start <= d <= dt_end, solarcf_filtered)

pm_scen = filter(:scenario => ==(scenario_id), solarpmax_filtered)
cf_scen = filter(:scenario => ==(scenario_id), solarcf_filtered)

id_gen_to_name = get_map_from_df(data["generator"], :id_gen, :name)
gen_ids = unique(pm_scen[!, :id_gen])
labels  = [id_gen_to_name[gid] for gid in gen_ids]

# --- Build merged DataFrame ---
merged_all = DataFrame()
for gid in gen_ids
    pm = filter(:id_gen => ==(gid), pm_scen)
    cf = filter(:id_gen => ==(gid), cf_scen)
    merged = innerjoin(pm, cf, on = :date => :datetime, makeunique = true)
    sort!(merged, :date)

    # Solar: directly multiply power output by CF (no capacity cap)
    merged[!, :pmax_corrected] = merged[!, :value] .* merged[!, :value_1]

    append!(merged_all, select(merged, :date, :id_gen, :value, :value_1, :pmax_corrected))
end

dates = sort(unique(merged_all[!, :date]))

# --- Build matrices ---
function build_matrix_from(df, val_col)
    hcat([
        begin
            sub = filter(:id_gen => ==(gid), df)
            sort!(sub, :date)
            sub[!, val_col]
        end
        for gid in gen_ids
    ]...)
end

before_gw = build_matrix_from(merged_all, :value)           ./ 1000
after_gw  = build_matrix_from(merged_all, :pmax_corrected)  ./ 1000

# --- PlotlyJS stacked area, two subplots ---
colors = [
    "#4e79a7", "#f28e2b", "#e15759", "#76b7b2", "#59a14f",
    "#edc948", "#b07aa1", "#ff9da7", "#9c755f", "#bab0ac",
    "#d37295", "#499894",
]

traces_before = [
    scatter(
        x           = dates,
        y           = before_gw[:, i],
        name        = labels[i],
        stackgroup  = "before",
        fill        = "tonexty",
        mode        = "lines",
        legendgroup = labels[i],
        line        = attr(color = colors[i])
    )
    for i in 1:length(labels)
]

traces_after = [
    scatter(
        x           = dates,
        y           = after_gw[:, i],
        name        = labels[i],
        stackgroup  = "after",
        fill        = "tonexty",
        mode        = "lines",
        legendgroup = labels[i],
        showlegend  = false,
        xaxis       = "x2",
        yaxis       = "y2",
        line        = attr(color = colors[i])
    )
    for i in 1:length(labels)
]

layout = Layout(
    title  = "Solar Power — Before vs After CF Correction",
    xaxis  = attr(title = "",     domain = [0, 1], anchor = "y"),
    yaxis  = attr(title = "Power Output (GW)", domain = [0.55, 1.0], anchor = "x"),
    xaxis2 = attr(title = "Date", domain = [0, 1], anchor = "y2"),
    yaxis2 = attr(title = "Power Output (GW)", domain = [0.0, 0.45], anchor = "x2"),
    legend = attr(x = 1.02, y = 1.0),
    annotations = [
        attr(text = "Before CF Correction", x = 0.5, y = 1.02, xref = "paper", yref = "paper", showarrow = false, font = attr(size = 13)),
        attr(text = "After CF Correction",  x = 0.5, y = 0.47, xref = "paper", yref = "paper", showarrow = false, font = attr(size = 13)),
    ],
)

Plot([traces_before; traces_after], layout)

## Solar — Before vs After CF (direct multiply with power output)
id_gen = 100

pm_solar = filter(:id_gen => ==(id_gen), pm_scen)
cf_solar  = filter(:id_gen => ==(id_gen), pvmodcf_roofpv_sched)

merged = innerjoin(pm_solar, cf_solar, on = :date => :datetime, makeunique = true)
sort!(merged, :date)

println(names(merged))
println(merged[1:5, :])

plt = Plots.plot(
    layout      = (2, 1),
    size        = (1000, 600),
    left_margin = 10mm,
    link        = :x,
)

Plots.plot!(merged[!, :date], merged[!, :value];
    label   = "Before (pmax)",
    ylabel  = "Power (MW)",
    title   = "SOLAR — Before vs After CF",
    subplot = 1,
)

Plots.plot!(merged[!, :date], merged[!, :value] .* merged[!, :value_1];
    label   = "After (pmax × CF)",
    subplot = 1,
)

Plots.plot!(merged[!, :date], merged[!, :value_1];
    label   = "CF",
    ylabel  = "CF (p.u.)",
    title   = "SOLAR — Correction Factor",
    xlabel  = "Date",
    subplot = 2,
    color   = :orange,
    xticks     = (dt_start:Hour(6):dt_end, Dates.format.(dt_start:Hour(6):dt_end, "dd HH:MM")),
)

plt

# Conclusion: Historically, peak ambient temperatures during Australian summer heat extremes occur in the late afternoon (approximately 4–6 pm), lagging behind peak solar irradiance (around 11 am–1 pm). This means solar power may experience only modest derating during peak irradiance, while stronger derating often occurs when solar irradiance is already declining, potentially reducing the overall impact on energy output.
