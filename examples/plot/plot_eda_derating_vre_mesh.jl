## Wind
# For different colors between REZ
using Dates
using DataFrames
using Statistics
using PlotlyJS
import PlotlyJS: scatter, Layout, Plot, attr

# --- choose one bus ---
id_bus_sel = 1  # NQ
scenario_sel = 1

# --- time window ---
dt_start = DateTime("2038-01-23 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS")
dt_end   = DateTime("2038-01-25 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS")

# df_bus name is reserved for data["bus"] elsewhere; use df_bus_vre here.
df_bus_vre = filter(:scenario => ==(scenario_sel), rez_windcf_bus)
df_bus_vre = filter(:id_bus => ==(id_bus_sel), df_bus_vre)

df_bus_vre[!, :datetime] = DateTime.(df_bus_vre[!, :date], dateformat"yyyy-mm-dd HH:MM:SS")
df_bus_vre = filter(:datetime => d -> dt_start <= d <= dt_end, df_bus_vre)
sort!(df_bus_vre, [:id_rez, :id_rez_mesh, :datetime])

# --- bus label (handles empty + missing) ---
bus_name = let
    if nrow(df_bus_vre) == 0
        "bus $(id_bus_sel)"
    else
        nm = collect(skipmissing(df_bus_vre.bus_name))
        isempty(nm) ? "bus $(id_bus_sel)" : first(nm)
    end
end

# --- compute mean per timestamp ---
# overall mean (across all meshes at the bus)
df_mean = combine(groupby(df_bus_vre, [:scenario, :datetime]), :value => mean => :cf_mean)
sort!(df_mean, :datetime)

# NEW: mean per REZ (across meshes in that REZ) at the bus
df_mean_rez = combine(
    groupby(df_bus_vre, [:scenario, :datetime, :id_rez, :rez_name]),
    :value => mean => :cf_mean_rez
)
sort!(df_mean_rez, [:id_rez, :datetime])

# --- colors: one base RGB per REZ, then use alpha for mesh vs mean ---
# (repeatable palette; extend if you have >10 REZ at a bus)
palette_rgb = [
    (31, 119, 180),  # blue
    (255, 127, 14),  # orange
    (44, 160, 44),   # green
    (214, 39, 40),   # red
    (148, 103, 189), # purple
    (140, 86, 75),   # brown
    (227, 119, 194), # pink
    (127, 127, 127), # gray
    (188, 189, 34),  # olive
    (23, 190, 207),  # cyan
]
rgba(rgb::NTuple{3,Int}, a::Real) = "rgba($(rgb[1]),$(rgb[2]),$(rgb[3]),$(Float64(a)))"

rez_keys = unique(select(df_bus_vre, :id_rez, :rez_name))
sort!(rez_keys, :id_rez)

rez_to_rgb = Dict{Int, NTuple{3,Int}}()
for (i, r) in enumerate(eachrow(rez_keys))
    rez_to_rgb[r.id_rez] = palette_rgb[mod1(i, length(palette_rgb))]
end

mesh_alpha = 0.18
mean_alpha = 1.0

# --- build traces ---
mesh_traces = PlotlyJS.GenericTrace[]

# NEW: group meshes by REZ so they get the same shade
for r in eachrow(rez_keys)
    id_rez = r.id_rez
    rez_name = r.rez_name

    base_rgb = rez_to_rgb[id_rez]
    mesh_color = rgba(base_rgb, mesh_alpha)

    # plot each mesh line (transparent) for this REZ
    mesh_ids_rez = unique(df_bus_vre.id_rez_mesh[df_bus_vre.id_rez .== id_rez])
    for mid in mesh_ids_rez
        sub = view(df_bus_vre, (df_bus_vre.id_rez_mesh .== mid) .& (df_bus_vre.id_rez .== id_rez), :)
        push!(mesh_traces,
            scatter(
                x = sub.datetime,
                y = sub.value,
                mode = "lines",
                name = "REZ $(id_rez): $(rez_name)", # legend handled by mean line
                showlegend = false,
                line = attr(color = mesh_color, width = 1),
                hovertemplate = "REZ: %{customdata[1]}<br>mesh %{customdata[2]}<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
                customdata = hcat(fill(string(rez_name), nrow(sub)), fill(string(mid), nrow(sub))),
            )
        )
    end
end

# NEW: mean line per REZ (opaque, shown in legend)
mean_rez_traces = PlotlyJS.GenericTrace[]
for r in eachrow(rez_keys)
    id_rez = r.id_rez
    rez_name = r.rez_name
    base_rgb = rez_to_rgb[id_rez]
    mean_color = rgba(base_rgb, mean_alpha)

    subm = view(df_mean_rez, df_mean_rez.id_rez .== id_rez, :)
    push!(mean_rez_traces,
        scatter(
            x = subm.datetime,
            y = subm.cf_mean_rez,
            mode = "lines",
            name = "REZ $(id_rez): $(rez_name) mean",
            line = attr(color = mean_color, width = 3),
            hovertemplate = "REZ mean<br>REZ: $(rez_name)<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
        )
    )
end

# OPTIONAL: overall bus mean (black)
overall_mean_trace = scatter(
    x = df_mean.datetime,
    y = df_mean.cf_mean,
    mode = "lines",
    name = "bus mean",
    line = attr(color = "rgba(0,0,0,1.0)", width = 4, dash = "dash"),
    hovertemplate = "bus mean<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
)

# OPTIONAL 2: low-spatial-granularity (1 profile per bus)
windcf_low = copy(windcf_sched)
windcf_low[!, :datetime] = DateTime.(windcf_low[!, :date], dateformat"yyyy-mm-dd HH:MM:SS")

# add id_bus onto wind CF rows
windcf_low = leftjoin(
    windcf_low,
    select(data["generator"], :id_gen, :id_bus);
    on = :id_gen
)

# keep same scenario + bus + window
scenario_sel = 1  # set to match your plot
windcf_low = filter(:scenario => ==(scenario_sel), windcf_low)
windcf_low = filter(:id_bus => ==(id_bus_sel), windcf_low)
windcf_low = filter(:datetime => d -> dt_start <= d <= dt_end, windcf_low)
sort!(windcf_low, :datetime)

windcf_low_trace = scatter(
    x = windcf_low.datetime,
    y = windcf_low.value,
    mode = "lines",
    name = "low-granularity CF (bus profile)",
    line = attr(color = "rgba(90,90,90,0.95)", width = 3, dash = "dash"),
    hovertemplate = "low-gran CF<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
)

layout = Layout(
    title = "REZ Wind CF — meshes + REZ means (bus $(id_bus_sel): $(bus_name))",
    xaxis = attr(title = "Date"),
    yaxis = attr(title = "CF (p.u.)"),
    width = 1100,
    height = 500,
    legend = attr(x = 1.02, y = 1.0),
    margin = attr(l = 70, r = 40, t = 70, b = 60),
    annotations = [
        attr(
            x = 0.01, y = 0.99, xref = "paper", yref = "paper",
            xanchor = "left", yanchor = "top",
            text = "bus $(id_bus_sel): $(bus_name)",
            showarrow = false,
            font = attr(size = 12, color = "black"),
            bgcolor = "rgba(255,255,255,0.7)",
            bordercolor = "rgba(0,0,0,0.2)",
            borderwidth = 1,
        )
    ],
)

plt = Plot([mesh_traces...; mean_rez_traces...; overall_mean_trace; windcf_low_trace], layout)
plt

## LargePV
using Dates
using DataFrames
using Statistics
using PlotlyJS
import PlotlyJS: scatter, Layout, Plot, attr

# --- choose one bus ---
id_bus_sel = 1  # NQ
# id_bus_sel = 8  # SNSW

scenario_sel = 1

# --- time window ---
dt_start = DateTime("2038-01-23 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS")
dt_end   = DateTime("2038-01-25 00:00:00", dateformat"yyyy-mm-dd HH:MM:SS")

# --- prep: filter + parse datetimes (mesh-level + joined bus metadata) ---
df_bus_vre = filter(:scenario => ==(scenario_sel), rez_pvmodcf_largepv_bus)
df_bus_vre = filter(:id_bus => ==(id_bus_sel), df_bus_vre)

df_bus_vre[!, :datetime] = DateTime.(df_bus_vre[!, :date], dateformat"yyyy-mm-dd HH:MM:SS")
df_bus_vre = filter(:datetime => d -> dt_start <= d <= dt_end, df_bus_vre)
sort!(df_bus_vre, [:id_rez, :id_rez_mesh, :datetime])

# --- aggregated REZ mean series (already computed in rez_pvmodcf_largepv_bus_mean) ---
df_mean_rez = filter(:scenario => ==(scenario_sel), rez_pvmodcf_largepv_bus_mean)
df_mean_rez = filter(:id_bus => ==(id_bus_sel), df_mean_rez)

df_mean_rez[!, :datetime] = DateTime.(df_mean_rez[!, :date], dateformat"yyyy-mm-dd HH:MM:SS")
df_mean_rez = filter(:datetime => d -> dt_start <= d <= dt_end, df_mean_rez)
sort!(df_mean_rez, [:id_rez, :datetime])

# --- bus label (handles empty + missing) ---
bus_name = let
    if nrow(df_bus_vre) == 0
        "bus $(id_bus_sel)"
    else
        nm = collect(skipmissing(df_bus_vre.bus_name))
        isempty(nm) ? "bus $(id_bus_sel)" : first(nm)
    end
end

# --- overall bus mean across all meshes (all REZ combined) ---
df_mean_bus = combine(
    groupby(df_bus_vre, [:scenario, :datetime]),
    :value => mean => :cf_mean_bus
)
sort!(df_mean_bus, :datetime)

# --- colors: one base RGB per REZ, alpha for mesh vs mean ---
palette_rgb = [
    (31, 119, 180),  # blue
    (255, 127, 14),  # orange
    (44, 160, 44),   # green
    (214, 39, 40),   # red
    (148, 103, 189), # purple
    (140, 86, 75),   # brown
    (227, 119, 194), # pink
    (127, 127, 127), # gray
    (188, 189, 34),  # olive
    (23, 190, 207),  # cyan
]
rgba(rgb::NTuple{3,Int}, a::Real) = "rgba($(rgb[1]),$(rgb[2]),$(rgb[3]),$(Float64(a)))"

rez_keys = unique(select(df_bus_vre, :id_rez, :rez_name))
sort!(rez_keys, :id_rez)

rez_to_rgb = Dict{Int, NTuple{3,Int}}()
for (i, r) in enumerate(eachrow(rez_keys))
    rez_to_rgb[r.id_rez] = palette_rgb[mod1(i, length(palette_rgb))]
end

mesh_alpha = 0.18
mean_alpha = 1.0

# --- build traces ---
mesh_traces = PlotlyJS.GenericTrace[]
mean_rez_traces = PlotlyJS.GenericTrace[]

# Mesh traces, grouped by REZ (same shade within REZ)
for r in eachrow(rez_keys)
    id_rez = r.id_rez
    rez_name = r.rez_name
    base_rgb = rez_to_rgb[id_rez]

    mesh_color = rgba(base_rgb, mesh_alpha)

    mesh_ids_rez = unique(df_bus_vre.id_rez_mesh[df_bus_vre.id_rez .== id_rez])
    for mid in mesh_ids_rez
        sub = view(df_bus_vre, (df_bus_vre.id_rez .== id_rez) .& (df_bus_vre.id_rez_mesh .== mid), :)
        push!(mesh_traces,
            scatter(
                x = sub.datetime,
                y = sub.value,
                mode = "lines",
                name = "REZ $(id_rez): $(rez_name)",
                showlegend = false,
                line = attr(color = mesh_color, width = 1),
                hovertemplate = "REZ: %{customdata[1]}<br>mesh %{customdata[2]}<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
                customdata = hcat(fill(string(rez_name), nrow(sub)), fill(string(mid), nrow(sub))),
            )
        )
    end

    # REZ mean trace (from rez_pvmodcf_largepv_bus_mean)
    subm = view(df_mean_rez, df_mean_rez.id_rez .== id_rez, :)
    mean_color = rgba(base_rgb, mean_alpha)

    push!(mean_rez_traces,
        scatter(
            x = subm.datetime,
            y = subm.cf_mean,
            mode = "lines",
            name = "REZ $(id_rez): $(rez_name) mean",
            line = attr(color = mean_color, width = 3),
            hovertemplate = "REZ mean<br>REZ: $(rez_name)<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
        )
    )
end

# Overall bus mean (all REZ combined) — black dashed
overall_mean_trace = scatter(
    x = df_mean_bus.datetime,
    y = df_mean_bus.cf_mean_bus,
    mode = "lines",
    name = "bus mean (all REZ)",
    line = attr(color = "rgba(0,0,0,1.0)", width = 4, dash = "dash"),
    hovertemplate = "bus mean<br>%{x}<br>cf=%{y:.3f}<extra></extra>",
)

layout = Layout(
    title = "REZ PV module CF — meshes + REZ means (bus $(id_bus_sel): $(bus_name))",
    xaxis = attr(title = "Date"),
    yaxis = attr(title = "CF (p.u.)"),
    width = 1100,
    height = 500,
    legend = attr(x = 1.02, y = 1.0),
    margin = attr(l = 70, r = 40, t = 70, b = 60),
    annotations = [
        attr(
            x = 0.01, y = 0.99, xref = "paper", yref = "paper",
            xanchor = "left", yanchor = "top",
            text = "bus $(id_bus_sel): $(bus_name)",
            showarrow = false,
            font = attr(size = 12, color = "black"),
            bgcolor = "rgba(255,255,255,0.7)",
            bordercolor = "rgba(0,0,0,0.2)",
            borderwidth = 1,
        )
    ],
)

plt = Plot([mesh_traces...; mean_rez_traces...; overall_mean_trace], layout)
plt
