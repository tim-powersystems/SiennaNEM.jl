using DataFrames
using Dates
using PlotlyJS

"""
    plot_line_derating_ts(
        fwcap_sched_lin,
        rvcap_sched_lin,
        ta_sched_lin,
        fwcap_summer_lin,
        rvcap_summer_lin,
        line_name_lin;
        dtfmt=dateformat"yyyy-mm-dd HH:MM:SS",
    ) -> PlotlyJS.Plot

Plot time series for ONE line:
- FW derated capacity (fwcap_sched_lin.value)
- RV derated capacity (rvcap_sched_lin.value)
- Base summer capacities (horizontal): fwcap_summer_lin and rvcap_summer_lin
- Temperature (ta_sched_lin.value) on secondary y-axis

Inputs are expected to already be filtered to the same `id_lin` (and same scenario if you care).
DataFrames must have columns: `:date` (string-ish) and `:value` (Float64).
"""
function plot_line_derating_ts(
    fwcap_sched_lin::DataFrame,
    rvcap_sched_lin::DataFrame,
    ta_sched_lin::DataFrame,
    fwcap_summer_lin::Real,
    rvcap_summer_lin::Real,
    line_name_lin;
    dtfmt::DateFormat = dateformat"yyyy-mm-dd HH:MM:SS",
)
    nrow(fwcap_sched_lin) == 0 && error("fwcap_sched_lin is empty")
    nrow(rvcap_sched_lin) == 0 && error("rvcap_sched_lin is empty")
    nrow(ta_sched_lin) == 0 && error("ta_sched_lin is empty")

    # parse dt (robust for String31 etc)
    fw_dt = DateTime.(String.(fwcap_sched_lin.date), dtfmt)
    rv_dt = DateTime.(String.(rvcap_sched_lin.date), dtfmt)
    ta_dt = DateTime.(String.(ta_sched_lin.date), dtfmt)

    # align by timestamp (inner join on dt)
    fw = DataFrame(dt=fw_dt, fw_mw=Float64.(fwcap_sched_lin.value))
    rv = DataFrame(dt=rv_dt, rv_mw=Float64.(rvcap_sched_lin.value))
    ta = DataFrame(dt=ta_dt, temp_c=Float64.(ta_sched_lin.value))

    sort!(fw, :dt); sort!(rv, :dt); sort!(ta, :dt)

    df = innerjoin(ta, fw, on=:dt)
    df = innerjoin(df, rv, on=:dt)
    nrow(df) == 0 && error("No overlapping timestamps between FW/RV/temp after join")

    x = df.dt
    ttl = "Line $(line_name_lin) derating"

    tr_fw = PlotlyJS.scatter(x=x, y=df.fw_mw, mode="lines", name="FW derated", yaxis="y1")
    tr_rv = PlotlyJS.scatter(x=x, y=df.rv_mw, mode="lines", name="RV derated", yaxis="y1")

    tr_fw_base = PlotlyJS.scatter(
        x=x, y=fill(Float64(fwcap_summer_lin), length(x)),
        mode="lines", name="fwcap_summer (base)",
        line=PlotlyJS.attr(dash="dash", width=2),
        yaxis="y1",
    )
    tr_rv_base = PlotlyJS.scatter(
        x=x, y=fill(Float64(rvcap_summer_lin), length(x)),
        mode="lines", name="rvcap_summer (base)",
        line=PlotlyJS.attr(dash="dash", width=2),
        yaxis="y1",
    )

    tr_t = PlotlyJS.scatter(
        x=x, y=df.temp_c,
        mode="lines", name="Temperature (°C)",
        line=PlotlyJS.attr(color="black", width=2),
        yaxis="y2",
    )

    lay = PlotlyJS.Layout(
        title=ttl,
        xaxis=PlotlyJS.attr(title="Time"),
        yaxis=PlotlyJS.attr(title="Capacity (MW)", side="left", rangemode="tozero"),
        yaxis2=PlotlyJS.attr(title="Temperature (°C)", overlaying="y", side="right"),

        # legend outside (right)
        legend=PlotlyJS.attr(
            orientation="v",
            x=1.20, xanchor="left",
            y=1.0,  yanchor="top",
        ),
        margin=PlotlyJS.attr(l=70, r=180, t=80, b=60),
    )

    p = PlotlyJS.plot([tr_fw, tr_rv, tr_fw_base, tr_rv_base, tr_t], lay)

    return p
end

id_lin = 9
fwcap_sched_lin = filter(:id_lin => ==(id_lin), fwcap_sched)
rvcap_sched_lin = filter(:id_lin => ==(id_lin), rvcap_sched)
ta_sched_lin = filter(:id_lin => ==(id_lin), line_ta_df)
fwcap_summer_lin = fwcap_summer = filter(:id_lin => ==(id_lin), data["line"])[1, :fwcap_summer]
rvcap_summer_lin = rvcap_summer = filter(:id_lin => ==(id_lin), data["line"])[1, :rvcap_summer]
line_name_lin = filter(:id_lin => ==(id_lin), data["line"])[1, :alias]

p = plot_line_derating_ts(
    fwcap_sched_lin, rvcap_sched_lin, ta_sched_lin,
    fwcap_summer_lin, rvcap_summer_lin, line_name_lin;
)
display(p)

# outpath_html=joinpath(@__DIR__, "line$(id_lin)_derating.html"),
