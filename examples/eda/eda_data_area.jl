# NOTE:
#   data["area"] is not from .csv and .arrow, but from
# SiennaNEM.read_data.add_area_df!

using SiennaNEM
using CSV

method_number = 3
# date_start = "20380120"
# date_end = "20380126"
# era5_date = "20240213"
date_start = "20400116"  # middle at 20400119
date_end = "20400122"  # middle at 20400119
era5_date = "20170210"
window_name = "7d"

bus_to_area = SiennaNEM.get_map_from_df(data["bus"], :id_bus, :id_area)
SiennaNEM.add_id_area_col!(data["generator"], bus_to_area)
SiennaNEM.add_area_df!(data)

"""
    add_data_col_by_id!(
    df, area_df;
    id_col=:id_area,
    area_name_col=:area_name,
    area_df_id=:id_area,
    area_df_name=:name,
)

Add an `area_name` column to `df` by matching `df[id_area_col]` with `area_df[area_df_id]`
and using `area_df[area_df_name]` as the label.

- Requires `df` to already have `id_area_col`.
- Throws if an `id_area` in `df` is not present in `area_df`.
"""
function add_data_col_by_id!(
    df, map;
    id_col::Symbol=:id_area,
    data_col::Symbol=:area_name,
)
    # NOTE: area_to_name is a constant from SiennaNEM.const
    df[!, data_col] = [map[id] for id in df[!, id_col]]
end

add_data_col_by_id!(data["bus"], SiennaNEM.area_to_name; data_col=:area_name)
add_data_col_by_id!(data["bus"], SiennaNEM.area_to_tref_peak_demand; data_col=:tref_peak_demand)
add_data_col_by_id!(data["bus"], SiennaNEM.area_to_tref_summer; data_col=:tref_summer)
add_data_col_by_id!(data["bus"], SiennaNEM.area_to_tref_winter; data_col=:tref_winter)

data["bus"]
# 12×11 DataFrame
#  Row │ id_bus  name    alias                           active  latitude  longitude  id_area  area_name  tref_summer  tref_winter  tref_peak_demand 
#      │ Int64   String  String                          Bool    Float64   Float64    Int64    String     Float64      Float64      Float64          
# ─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │      1  NQ      Northern Queensland               true  -17.7938    145.564        1  QLD               32.0         15.0              32.0
#    2 │      2  CQ      Central Queensland                true  -22.8242    149.404        1  QLD               32.0         15.0              32.0
#    3 │      3  GG      Gladstone Grid                    true  -23.8429    151.249        1  QLD               32.0         15.0              32.0
#    4 │      4  SQ      Southern Queensland               true  -27.4766    153.03         1  QLD               32.0         15.0              32.0
#    5 │      5  NNSW    Northern New South Wales          true  -30.5047    151.652        2  NSW               32.0          9.0              32.0
#    6 │      6  CNSW    Central New South Wales           true  -33.4833    150.158        2  NSW               32.0          9.0              32.0
#    7 │      7  SNW     Sydney, Newcastle & Wollongong    true  -33.865     151.209        2  NSW               32.0          9.0              32.0
#    8 │      8  SNSW    Southern New South Wales          true  -35.111     147.36         2  NSW               32.0          9.0              32.0
#    9 │      9  VIC     Victoria                          true  -37.7661    144.943        3  VIC               32.0          8.0              32.0
#   10 │     10  TAS     Tasmania                          true  -42.8806    147.325        4  TAS               35.0         11.0              35.0
#   11 │     11  CSA     Central South Australia           true  -34.8027    138.522        5  SA                 7.7          1.2               7.7
#   12 │     12  SESA    South East South Australia        true  -37.6047    140.837        5  SA                 7.7          1.2               7.7

# NOTE: We can see that for all buses, tref_peak_demand >= tref_summer >= tref_winter.
# We can use this as boundary in deciding line thermal derating in different seasons.

add_data_col_by_id!(data["area"], SiennaNEM.area_to_tref_peak_demand; data_col=:tref_peak_demand)
add_data_col_by_id!(data["area"], SiennaNEM.area_to_tref_summer; data_col=:tref_summer)
add_data_col_by_id!(data["area"], SiennaNEM.area_to_tref_winter; data_col=:tref_winter)
data["area"]
# 5×8 DataFrame
#  Row │ id_area  name    peak_active_power  peak_reactive_power  max_pmax  tref_peak_demand  tref_summer  tref_winter 
#      │ Int64    String  Float64            Float64              Float64   Float64           Float64      Float64     
# ─────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │       1  QLD                   0.0                  0.0   2042.66              32.0         32.0         15.0
#    2 │       2  NSW                   0.0                  0.0   2345.46              32.0         32.0          9.0
#    3 │       3  VIC                   0.0                  0.0   5362.16              32.0         32.0          8.0
#    4 │       4  TAS                   0.0                  0.0    563.35              35.0         35.0         11.0
#    5 │       5  SA                    0.0                  0.0   2435.99               7.7          7.7          1.2

# NOTE:
#   1. fwcap is forward power flow capacity
#   2. rvcap is reverse power flow capacity
SiennaNEM.add_id_area_col!(data["line"], bus_to_area; bus_col=:id_bus_from, area_col=:id_area_from)
SiennaNEM.add_id_area_col!(data["line"], bus_to_area; bus_col=:id_bus_to, area_col=:id_area_to)
add_data_col_by_id!(data["line"], SiennaNEM.area_to_name; id_col=:id_area_from, data_col=:area_from)
add_data_col_by_id!(data["line"], SiennaNEM.area_to_name; id_col=:id_area_to, data_col=:area_to)
transform!(
    data["line"],
    :id_lin => ByRow(id -> get(line_to_rvcap_summer, id, NaN)) => :rvcap_summer,
)
transform!(
    data["line"],
    :id_lin => ByRow(id -> get(line_to_fwcap_summer, id, NaN)) => :fwcap_summer,
)
transform!(
    data["line"],
    :id_lin => ByRow(id -> get(line_to_rvcap_peak_demand, id, NaN)) => :rvcap_peak_demand,
)
transform!(
    data["line"],
    :id_lin => ByRow(id -> get(line_to_fwcap_peak_demand, id, NaN)) => :fwcap_peak_demand,
)

# NOTE: We should not fill NaN for new units without any data of summer and winter flow.
# for these cases, we should augment their line reference temperature instead later.
# Leaving them NaN is better as mark for later processing.

show(
    filter(
        :investment => ==(false), filter(:active => ==(true), data["line"])
    )[:, [:id_lin, :name, :alias, :area_from, :area_to, :id_bus_from, :id_bus_to, :fwcap, :rvcap, :fwcap_summer, :rvcap_summer, :fwcap_peak_demand, :rvcap_peak_demand]],
    allrows=true, allcols=true
)
# 15×13 DataFrame
#  Row │ id_lin  name        alias                  area_from  area_to  id_bus_from  id_bus_to  fwcap     rvcap     fwcap_summer  rvcap_summer  fwcap_peak_demand  rvcap_peak_demand 
#      │ Int64   String      String                 String     String   Int64        Int64      Float64?  Float64?  Float64       Float64       Float64            Float64           
# ─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │      1  CQ->NQ      CQ->NQ                 QLD        QLD                2          1    1400.0    1400.0        1200.0        1200.0             1200.0             1200.0
#    2 │      2  CQ->GG      CQ->GG                 QLD        QLD                2          3    1050.0    1100.0         700.0         750.0              700.0              750.0
#    3 │      3  SQ->CQ      SQ->CQ                 QLD        QLD                4          2    1100.0    2100.0        1100.0        2100.0             1100.0             2100.0
#    4 │      4  NNSW->SQ    QNI North              NSW        QLD                5          4     745.0    1170.0         745.0        1165.0              685.0             1205.0
#    5 │      5  NNSW->SQ    Terranora              NSW        QLD                5          4      50.0     200.0          50.0         150.0                0.0              130.0
#    6 │      6  CNSW->NNSW  QNI South              NSW        NSW                6          5     910.0    1025.0         910.0         930.0              910.0              930.0
#    7 │      7  CNSW->SNW   CNSW->SNW North        NSW        NSW                6          7    4730.0    4730.0        4490.0        4490.0             4490.0             4490.0
#    8 │      8  CNSW->SNW   CNSW->SNW South        NSW        NSW                6          7    2720.0    2720.0        2540.0        2540.0             2540.0             2540.0
#    9 │      9  SNSW->CNSW  VNI North              NSW        NSW                8          6    2950.0    2590.0        2700.0        2320.0             2700.0             2320.0
#   10 │     10  VIC->SNSW   VNI South              VIC        NSW                9          8    1000.0     400.0        1000.0         400.0              870.0              400.0
#   11 │     11  VIC->SESA   Heywood                VIC        SA                 9         12     650.0     650.0         650.0         650.0              650.0              650.0
#   12 │     12  SESA->CSA   SESA->CSA              SA         SA                12         11     650.0     650.0         650.0         650.0              650.0              650.0
#   13 │     13  VIC->CSA    Murraylink             VIC        SA                 9         11     220.0     200.0         220.0         200.0              220.0              100.0
#   14 │     14  TAS->VIC    Basslink               TAS        VIC               10          9     594.0     478.0         594.0         478.0              594.0              478.0
#   15 │     15  SNSW->CSA   Project EnergyConnect  NSW        SA                 8         11     800.0     800.0         800.0         800.0              800.0              800.0

# NOTE: We don't actually need directional limit detection. We can ust use fwcap and rvcap
# independently.
# 
# transform!(
#     data["line"],
#     [:fwcap, :rvcap] =>
#         ByRow((fwcap, rvcap) -> (fwcap <= rvcap ? :fwcap : :rvcap)) =>
#             :dir_limit,
# )
# transform!(
#     data["line"],
#     [:dir_limit, :id_bus_from, :id_bus_to] =>
#         ByRow((dir, id_from, id_to) -> (dir === :fwcap ? id_from : id_to)) =>
#             :id_bus_limit,
# )
# SiennaNEM.add_id_area_col!(
#     data["line"], bus_to_area;
#     bus_col=:id_bus_limit, area_col=:id_area_limit
# )

# add tech
transform!(
    data["line"],
    :id_lin => ByRow(id -> get(line_to_tech, id, "ac_oh")) => :tech,
)
show(
    filter(
        :investment => ==(false), filter(:active => ==(true), data["line"])
    )[:, [:id_lin, :alias, :area_from, :area_to, :tech]],
    allrows=true, allcols=true
)
# 15×5 DataFrame
#  Row │ id_lin  alias                  area_from  area_to  tech   
#      │ Int64   String                 String     String   String 
# ─────┼───────────────────────────────────────────────────────────
#    1 │      1  CQ->NQ                 QLD        QLD      ac_oh
#    2 │      2  CQ->GG                 QLD        QLD      ac_oh
#    3 │      3  SQ->CQ                 QLD        QLD      ac_oh
#    4 │      4  QNI North              NSW        QLD      ac_oh
#    5 │      5  Terranora              NSW        QLD      dc_ug
#    6 │      6  QNI South              NSW        NSW      ac_oh
#    7 │      7  CNSW->SNW North        NSW        NSW      ac_oh
#    8 │      8  CNSW->SNW South        NSW        NSW      ac_oh
#    9 │      9  VNI North              NSW        NSW      ac_oh
#   10 │     10  VNI South              VIC        NSW      ac_oh
#   11 │     11  Heywood                VIC        SA       ac_oh
#   12 │     12  SESA->CSA              SA         SA       ac_oh
#   13 │     13  Murraylink             VIC        SA       dc_ug
#   14 │     14  Basslink               TAS        VIC      dc_ss
#   15 │     15  Project EnergyConnect  NSW        SA       ac_oh

# NOTE:
#   To get hypothetical tm (line maximum thermal limit), we need to get:
# 
#       t1, t2, pmax1, pmax2
# 
#   We use 1 as the winter and 2 as the summer. rvcap and fwcap in line data is from
# winter data, that is reverse and forward. We need to add rvcap and fwcap columns for
# summer first to fill the pmax2.
# 
#   Assume that we will only use fwcap and fwcap_summer (forward direction only). Then, we
# need to use t1 and t2, first from the :id_from then from the :id_to. 

# add tref
transform!(
    data["line"],
    :id_area_from =>
        ByRow(id -> get(SiennaNEM.area_to_tref_peak_demand, id, NaN)) =>
            :tref_peak_demand_from,
)
transform!(
    data["line"],
    :id_area_to =>
        ByRow(id -> get(SiennaNEM.area_to_tref_peak_demand, id, NaN)) =>
            :tref_peak_demand_to,
)
transform!(
    data["line"],
    :id_area_from =>
        ByRow(id -> get(SiennaNEM.area_to_tref_summer, id, NaN)) =>
            :tref_summer_from,
)
transform!(
    data["line"],
    :id_area_to =>
        ByRow(id -> get(SiennaNEM.area_to_tref_summer, id, NaN)) =>
            :tref_summer_to,
)
transform!(
    data["line"],
    :id_area_from =>
        ByRow(id -> get(SiennaNEM.area_to_tref_winter, id, NaN)) =>
            :tref_winter_from,
)
transform!(
    data["line"],
    :id_area_to =>
        ByRow(id -> get(SiennaNEM.area_to_tref_winter, id, NaN)) =>
            :tref_winter_to,
)

"""
Infer branch maximum conductor temperature t_max from two derating points.

Scalar-safe (works with `ByRow`). Returns NaN when inputs are not usable
(NaN/Inf or p_max_1 ≈ p_max_2).
"""
function infer_branch_thermal_t_max(t_1::Real, t_2::Real, p_max_1::Real, p_max_2::Real; atol::Real=0.0)
    t1 = Float64(t_1)
    t2 = Float64(t_2)
    p1 = Float64(p_max_1)
    p2 = Float64(p_max_2)

    if !(isfinite(t1) && isfinite(t2) && isfinite(p1) && isfinite(p2))
        return NaN
    end

    p1_sq = p1^2
    p2_sq = p2^2
    denom = p1_sq - p2_sq
    if abs(denom) <= atol
        return NaN
    end

    tm = (p1_sq * t2 - p2_sq * t1) / denom
    if tm < max(t1, t2)
        return NaN
    end
    return tm
end

# for ta <= tref_winter: cf = 1, use fwcap and rvcap, return (fwcap_winter, rvcap_winter)
# for tref_winter < ta <= tref_summer: tm1, use fwcap_summer and rvcap_summer, return (fwcap_winter, rvcap_winter) * cf 
# for tref_summer < ta <= tref_peak_demand: tm2, use fwcap_summer and rvcap_summer, return (fwcap_summer, rvcap_winter) * cf (fwcap_summer, rvcap_winter)
# for tref_peak_demand < ta: tm3, use fwcap_peak_demand and rvcap_peak_demand, return (fwcap_peak_demand, rvcap_winter) * cf 
# tm3 is min(tm2, tm_cap)
# 
# NOTE: Sometimes, tm = NaN due to no impact of temperature on the line rating for a
# specific piecewise region. In the case of tm == NaN:
# 
#   Region 1: return (fwcap_winter, rvcap_winter)
#   Region 2: return (fwcap_winter, rvcap_winter)
#   Region 3: return (fwcap_summer, rvcap_winter)
#   Region 4: return (fwcap_peak_demand, rvcap_winter) (actually impossible due to tm_cap)

# tm_cap = 250.0  # default for high-temperature conductors (ACSS)
# tm_cap = 100.0  # default for high, standard-temperature conductors (ACSR)
tm_cap = 90.0  # default for high, standard-temperature conductors

# for the forward flow: fwcap
transform!(
    data["line"],
    [:tref_winter_from, :tref_summer_from, :fwcap, :fwcap_summer] =>
        ByRow((tw, ts, pw, ps) -> infer_branch_thermal_t_max(tw, ts, pw, ps)) =>
            :tm1_from_fwcap,
)
transform!(
    data["line"],
    [:tref_winter_to, :tref_summer_to, :fwcap, :fwcap_summer] =>
        ByRow((tw, ts, pw, ps) -> infer_branch_thermal_t_max(tw, ts, pw, ps)) =>
            :tm1_to_fwcap,
)
transform!(
    data["line"],
    [:tref_summer_from, :tref_peak_demand_from, :fwcap_summer, :fwcap_peak_demand] =>
        ByRow((ts, tp, ps, pp) -> infer_branch_thermal_t_max(ts, tp, ps, pp)) =>
            :tm2_from_fwcap,
)
transform!(
    data["line"],
    [:tref_summer_to, :tref_peak_demand_to, :fwcap_summer, :fwcap_peak_demand] =>
        ByRow((ts, tp, ps, pp) -> infer_branch_thermal_t_max(ts, tp, ps, pp)) =>
            :tm2_to_fwcap,
)
transform!(
    data["line"],
    :tm2_from_fwcap =>
        ByRow(tm2 -> (isfinite(tm2) ? min(tm2, tm_cap) : tm_cap)) =>
            :tm3_from_fwcap,
)
transform!(
    data["line"],
    :tm2_to_fwcap =>
        ByRow(tm2 -> (isfinite(tm2) ? min(tm2, tm_cap) : tm_cap)) =>
            :tm3_to_fwcap,
)

# for the reverse flow: rvcap
transform!(
    data["line"],
    [:tref_winter_from, :tref_summer_from, :rvcap, :rvcap_summer] =>
        ByRow((tw, ts, pw, ps) -> infer_branch_thermal_t_max(tw, ts, pw, ps)) =>
            :tm1_from_rvcap,
)
transform!(
    data["line"],
    [:tref_winter_to, :tref_summer_to, :rvcap, :rvcap_summer] =>
        ByRow((tw, ts, pw, ps) -> infer_branch_thermal_t_max(tw, ts, pw, ps)) =>
            :tm1_to_rvcap,
)
transform!(
    data["line"],
    [:tref_summer_from, :tref_peak_demand_from, :rvcap_summer, :rvcap_peak_demand] =>
        ByRow((ts, tp, ps, pp) -> infer_branch_thermal_t_max(ts, tp, ps, pp)) =>
            :tm2_from_rvcap,
)
transform!(
    data["line"],
    [:tref_summer_to, :tref_peak_demand_to, :rvcap_summer, :rvcap_peak_demand] =>
        ByRow((ts, tp, ps, pp) -> infer_branch_thermal_t_max(ts, tp, ps, pp)) =>
            :tm2_to_rvcap,
)
transform!(
    data["line"],
    :tm2_from_rvcap =>
        ByRow(tm2 -> (isfinite(tm2) ? min(tm2, tm_cap) : tm_cap)) =>
            :tm3_from_rvcap,
)
transform!(
    data["line"],
    :tm2_to_rvcap =>
        ByRow(tm2 -> (isfinite(tm2) ? min(tm2, tm_cap) : tm_cap)) =>
            :tm3_to_rvcap,
)

# Combine "from/to" without mixing directions:
# - forward (fwcap): take min(tm*_from_fwcap, tm*_to_fwcap)
# - reverse (rvcap): take min(tm*_from_rvcap, tm*_to_rvcap)
# If both are non-finite -> NaN (keep missingness)
transform!(
    data["line"],
    [:tm1_from_fwcap, :tm1_to_fwcap] =>
        ByRow((a, b) -> begin
            vals = (Float64(a), Float64(b))
            good = filter(isfinite, vals)
            isempty(good) ? NaN : minimum(good)
        end) => :tm1_fwcap,
)
transform!(
    data["line"],
    [:tm2_from_fwcap, :tm2_to_fwcap] =>
        ByRow((a, b) -> begin
            vals = (Float64(a), Float64(b))
            good = filter(isfinite, vals)
            isempty(good) ? NaN : minimum(good)
        end) => :tm2_fwcap,
)
transform!(
    data["line"],
    [:tm3_from_fwcap, :tm3_to_fwcap] =>
        ByRow((a, b) -> min(Float64(a), Float64(b))) => :tm3_fwcap,
)

transform!(
    data["line"],
    [:tm1_from_rvcap, :tm1_to_rvcap] =>
        ByRow((a, b) -> begin
            vals = (Float64(a), Float64(b))
            good = filter(isfinite, vals)
            isempty(good) ? NaN : minimum(good)
        end) => :tm1_rvcap,
)
transform!(
    data["line"],
    [:tm2_from_rvcap, :tm2_to_rvcap] =>
        ByRow((a, b) -> begin
            vals = (Float64(a), Float64(b))
            good = filter(isfinite, vals)
            isempty(good) ? NaN : minimum(good)
        end) => :tm2_rvcap,
)
transform!(
    data["line"],
    [:tm3_from_rvcap, :tm3_to_rvcap] =>
        ByRow((a, b) -> min(Float64(a), Float64(b))) => :tm3_rvcap,
)

show(filter(:investment => ==(false), filter(:active => ==(true), data["line"]))[:, [
        :id_lin, :alias, :area_from, :area_to, :tm1_fwcap, :tm2_fwcap, :tm3_fwcap, :tm1_rvcap, :tm2_rvcap, :tm3_rvcap
    ]],
    allrows=true, allcols=true
)

# fix tm for HVDC lines:
cols_tm = [:tm1_fwcap, :tm2_fwcap, :tm3_fwcap, :tm1_rvcap, :tm2_rvcap, :tm3_rvcap]
cols_tm_fwcap = [:tm1_fwcap, :tm2_fwcap, :tm3_fwcap]
# HVDC Terranora should be limited to:
#   1. To 46°C, the same as Murraylink for reverse flow (rvcap)
#   2. To 37.0°C for forward flow (fwcap) as specified by the operator
mask_terranora = data["line"].id_lin .== 5
data["line"][mask_terranora, cols_tm] .=
    ifelse.(
        isfinite.(data["line"][mask_terranora, cols_tm]),
        data["line"][mask_terranora, cols_tm],
        46.0
    )
data["line"][mask_terranora, cols_tm] .=
    min.(data["line"][mask_terranora, cols_tm], 46.0)
data["line"][mask_terranora, cols_tm_fwcap] .=
    min.(data["line"][mask_terranora, cols_tm_fwcap], 37.0)
# HVDC Murraylink is specified by the operator to have a 46°C thermal limit
data["line"][data["line"].id_lin.==13, cols_tm] .= 46.0
# HVDC Basslink (undersea cable) is not impacted by ambient temperature
data["line"][data["line"].id_lin.==14, cols_tm] .= NaN

# NOTE: Now, we need to add tref for each line as we can't use nodes. For this,
# we assume the lowest tref among the two ends as the line tref to be conservative.

transform!(
    data["line"],
    [:tref_peak_demand_from, :tref_peak_demand_to] =>
        ByRow((a, b) -> min(Float64(a), Float64(b))) => :tref_peak_demand,
)
transform!(
    data["line"],
    [:tref_summer_from, :tref_summer_to] =>
        ByRow((a, b) -> min(Float64(a), Float64(b))) => :tref_summer,
)
transform!(
    data["line"],
    [:tref_winter_from, :tref_winter_to] =>
        ByRow((a, b) -> min(Float64(a), Float64(b))) => :tref_winter,
)

# New ac_oh lines without any data of summer and winter flow should be derated based on their
# (default) line reference temperature.
cols_missing_ratings = [:fwcap_summer, :fwcap_peak_demand, :rvcap_summer, :rvcap_peak_demand]
mask_no_seasonal_data =
    (data["line"].tech .== "ac_oh") .&
    reduce(.&, (.!isfinite.(data["line"][!, c]) for c in cols_missing_ratings))
data["line"][mask_no_seasonal_data, cols_tm] .= constant_temperature["ac_oh_tm"]
data["line"][mask_no_seasonal_data, [:tref_peak_demand, :tref_summer, :tref_winter]] .=
    constant_temperature["ac_oh_tref"]
data["line"][mask_no_seasonal_data, :fwcap_summer] .= data["line"][mask_no_seasonal_data, :fwcap]
data["line"][mask_no_seasonal_data, :fwcap_peak_demand] .= data["line"][mask_no_seasonal_data, :fwcap]
data["line"][mask_no_seasonal_data, :rvcap_summer] .= data["line"][mask_no_seasonal_data, :rvcap]
data["line"][mask_no_seasonal_data, :rvcap_peak_demand] .= data["line"][mask_no_seasonal_data, :rvcap]

show(filter(:investment => ==(false), filter(:active => ==(true), data["line"]))[:, [
        :id_lin, :alias, :area_from, :area_to, :tref_peak_demand, :tref_summer, :tref_winter, :tm1_fwcap, :tm2_fwcap, :tm3_fwcap, :tm1_rvcap, :tm2_rvcap, :tm3_rvcap
    ]],
    allrows=true, allcols=true
)

# 15×13 DataFrame
#  Row │ id_lin  alias                  area_from  area_to  tref_peak_demand  tref_summer  tref_winter  tm1_fwcap  tm2_fwcap  tm3_fwcap  tm1_rvcap   tm2_rvcap  tm3_rvcap 
#      │ Int64   String                 String     String   Float64           Float64      Float64      Float64   Float64   Float64   Float64    Float64   Float64  
# ─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
#    1 │      1  CQ->NQ                 QLD        QLD                  37.0         32.0         15.0   79.0769  NaN        90.0       79.0769     NaN        90.0
#    2 │      2  CQ->GG                 QLD        QLD                  37.0         32.0         15.0   45.6     NaN        90.0       46.7683     NaN        90.0
#    3 │      3  SQ->CQ                 QLD        QLD                  37.0         32.0         15.0  NaN       NaN        90.0      NaN          NaN        90.0
#    4 │      4  QNI North              NSW        QLD                  37.0         32.0          9.0  NaN        64.3441   64.3441  2008.26       NaN        90.0
#    5 │      5  Terranora              NSW        QLD                  37.0         32.0          9.0   37.0      37.0      37.0       46.0         46.0      46.0
#    6 │      6  QNI South              NSW        NSW                  42.0         32.0          9.0  NaN       NaN        90.0      139.108      NaN        90.0
#    7 │      7  CNSW->SNW North        NSW        NSW                  42.0         32.0          9.0  241.546   NaN        90.0      241.546      NaN        90.0
#    8 │      8  CNSW->SNW South        NSW        NSW                  42.0         32.0          9.0  188.725   NaN        90.0      188.725      NaN        90.0
#    9 │      9  VNI North              NSW        NSW                  42.0         32.0          9.0  150.704   NaN        90.0      125.381      NaN        90.0
#   10 │     10  VNI South              VIC        NSW                  41.0         32.0          8.0  NaN        69.0218   69.0218   NaN          NaN        90.0
#   11 │     11  Heywood                VIC        SA                   41.0         32.0          8.0  NaN       NaN        90.0      NaN          NaN        90.0
#   12 │     12  SESA->CSA              SA         SA                   43.0         35.0         11.0  NaN       NaN        90.0      NaN          NaN        90.0
#   13 │     13  Murraylink             VIC        SA                   41.0         32.0          8.0   46.0      46.0      46.0       46.0         46.0      46.0
#   14 │     14  Basslink               TAS        VIC                   7.7          7.7          1.2  NaN       NaN       NaN        NaN          NaN       NaN
#   15 │     15  Project EnergyConnect  NSW        SA                   20.0         20.0         20.0   90.0      90.0      90.0       90.0         90.0      90.0

# TODO: what is the best logic for new dc_ug lines?

# New other lines without any data of summer and winter flow should be derated based on their
# (default) line capacity
cols_missing_ratings = [:fwcap_summer, :fwcap_peak_demand, :rvcap_summer, :rvcap_peak_demand]
mask_no_seasonal_data =
    reduce(.&, (.!isfinite.(data["line"][!, c]) for c in cols_missing_ratings))
data["line"][mask_no_seasonal_data, :fwcap_summer] .= data["line"][mask_no_seasonal_data, :fwcap]
data["line"][mask_no_seasonal_data, :fwcap_peak_demand] .= data["line"][mask_no_seasonal_data, :fwcap]
data["line"][mask_no_seasonal_data, :rvcap_summer] .= data["line"][mask_no_seasonal_data, :rvcap]
data["line"][mask_no_seasonal_data, :rvcap_peak_demand] .= data["line"][mask_no_seasonal_data, :rvcap]

# # print for debugging dc_ss lines
# ids = [14, 50, 51]
# show(
#     filter(:id_lin => in(ids), data["line"])[:, [
#         :id_lin, :name, :alias, :tech,
#         :tref_winter, :tref_summer, :tref_peak_demand,
#         :fwcap, :fwcap_summer, :fwcap_peak_demand,
#         :rvcap, :rvcap_summer, :rvcap_peak_demand,
#         :tm1_fwcap, :tm2_fwcap, :tm3_fwcap,
#         :tm1_rvcap, :tm2_rvcap, :tm3_rvcap,
#     ]],
#     allrows=true, allcols=true
# )

"""
    get_branch_thermal_capacity_ac_oh(
        ta,
        t1, t2, t3,
        p1, p2, p3,
        tm1, tm2, tm3,
    ) -> Float64

Compute the thermally derated branch capacity at ambient temperature `ta`,
using a 4-region piecewise model. Call once for forward flow (fwcap) and
once for reverse flow (rvcap).

    t1 = tref_winter, t2 = tref_summer, t3 = tref_peak_demand
    p1 = capacity at t1 (winter), p2 = capacity at t2 (summer), p3 = capacity at t3 (peak demand)
    tm1, tm2, tm3 = inferred conductor temperatures for regions 2, 3, 4

Regions:

| Region | Condition        | tm   | Base | CF reference |
|--------|------------------|------|------|--------------|
| 1      | `ta ≤ t1`        | —    | `p1` | —            |
| 2      | `t1 < ta ≤ t2`   | `tm1`| `p1` | `t1`         |
| 3      | `t2 < ta ≤ t3`   | `tm2`| `p2` | `t2`         |
| 4      | `ta > t3`        | `tm3`| `p3` | `t3`         |

CF shape:

    CF(ta) = sqrt(max(tm - ta, 0) / (tm - t_reference))

NaN fallback (when `tm` is NaN, no derating applies in that region):

| Region | NaN fallback |
|--------|--------------|
| 2      | `p1`         |
| 3      | `p2`         |
| 4      | `p3`         |
"""
function get_branch_thermal_capacity_ac_oh(
    ta::Real,
    t2::Real, t3::Real,
    p2::Real, p3::Real,
    tm2::Real, tm3::Real,
)
    ta = Float64(ta)

    function cf(tm::Float64, t_reference::Float64)
        isnan(tm) && return NaN
        return sqrt(max(tm - ta, 0.0) / (tm - t_reference))
    end

    # Winter to Summer interpolation is no longer used
    # if ta <= t1
    #     return Float64(p1)
    # elseif ta <= t2
    #     c = cf(Float64(tm1), Float64(t1))
    #     return isnan(c) ? Float64(p1) : Float64(p1) * c

    if ta <= t2
        return Float64(p2)
    elseif ta <= t3
        c = cf(Float64(tm2), Float64(t2))
        return isnan(c) ? Float64(p2) : Float64(p2) * c
    else
        c = cf(Float64(tm3), Float64(t3))
        return isnan(c) ? Float64(p3) : Float64(p3) * c
    end
end

"""
    get_branch_thermal_capacity_dc_ug(ta, tm, p) -> Float64

Compute derated capacity for DC underground (`dc_ug`) lines.

- `ta ≤ dc_ug_tref`              : return `p` (no reduction)
- `dc_ug_tref < ta ≤ tm`         : return `p * (1 - dc_ug_derating_rate * (ta - dc_ug_tref))`
- `ta > tm`                      : return `0.0`
"""
function get_branch_thermal_capacity_dc_ug(ta::Real, tm::Real, p::Real)
    ta = Float64(ta)
    tm = Float64(tm)
    p = Float64(p)

    if ta <= constant_temperature["dc_ug_tref"]
        return p
    elseif ta <= tm
        return p * (1.0 - constant_temperature["dc_ug_derating_rate"] * (ta - constant_temperature["dc_ug_tref"]))
    else
        return 0.0
    end
end

"""
    get_branch_thermal_capacity(ta_df, line_df, cols; notconstrained_lines, tech_col=:tech) -> DataFrame

Agnostic DataFrame version of thermal derating.

- `ta_df[:value]` is ambient temperature (°C)
- `cols` must be a 6-element vector/tuple of Symbols in this order:
    (t2, t3, p2, p3, tm2, tm3)
- `notconstrained_lines` is a vector of `id_lin` values that are NOT thermally derated.
  Lines present in this vector return the base capacity for the applicable region:
    - `ta ≤ t3` → `p2`
    - `ta > t3`  → `p3`
- joins `ta_df` with `line_df` on `:id_lin`
- overwrites `:value` with derated MW
- returns `:id, :id_lin, :scenario, :date, :value`

The t1, p1, and tm1 is for winter and no longer used.
"""
function get_branch_thermal_capacity(
    ta_df::DataFrame,
    line_df::DataFrame,
    cols;
    notconstrained_lines::Vector = Vector{Int}(),
    tech_col::Symbol = :tech,
)
    t2, t3, p2, p3, tm2, tm3 = cols

    df = leftjoin(ta_df, line_df; on=:id_lin)

    transform!(
        df,
        [:id_lin, tech_col, t2, t3, p2, p3, tm2, tm3, :value] =>
        ByRow((id_lin, tech, t2v, t3v, p2v, p3v, tm2v, tm3v, ta) -> begin

            # Not thermally constrained — return base capacity for region only
            if id_lin ∈ notconstrained_lines
                return ta <= t3v ? Float64(p2v) : Float64(p3v)
            end

            if tech == "ac_oh"
                get_branch_thermal_capacity_ac_oh(ta, t2v, t3v, p2v, p3v, tm2v, tm3v)
            elseif tech == "dc_ug"
                get_branch_thermal_capacity_dc_ug(ta, tm3v, p2v)
            else
                Float64(p2v)
            end
        end) => :value,
    )

    select(df, :id, :id_lin, :scenario, :date, :value)
end

# # For EDA and Testing
# # ambient temperature for derating (°C)
# # ta = 25.0  # for testing mild temperature
# # ta = 36.0  # for testing summer temperature
# # ta = 42.0  # for testing high temperature
# ta = 47.0  # for testing extreme temperature

# transform!(
#     data["line"],
#     [:tech,
#         :tref_winter, :tref_summer, :tref_peak_demand,
#         :fwcap, :fwcap_summer, :fwcap_peak_demand,
#         :tm1_fwcap, :tm2_fwcap, :tm3_fwcap] =>
#         ByRow((tech, args...) -> begin
#             if tech == "ac_oh"
#                 get_branch_thermal_capacity_ac_oh(ta, args...)
#             elseif tech == "dc_ug"
#                 # use tm3 as the conductor limit, p1 (fwcap) as base capacity
#                 t1, t2, t3, p1, p2, p3, tm1, tm2, tm3 = args
#                 get_branch_thermal_capacity_dc_ug(ta, tm3, p1)
#             else  # dc_ss
#                 Float64(args[4])  # p1 = fwcap, no derating
#             end
#         end) => :fwcap_derated,
# )
# transform!(
#     data["line"],
#     [:tech,
#         :tref_winter, :tref_summer, :tref_peak_demand,
#         :rvcap, :rvcap_summer, :rvcap_peak_demand,
#         :tm1_rvcap, :tm2_rvcap, :tm3_rvcap] =>
#         ByRow((tech, args...) -> begin
#             if tech == "ac_oh"
#                 get_branch_thermal_capacity_ac_oh(ta, args...)
#             elseif tech == "dc_ug"
#                 t1, t2, t3, p1, p2, p3, tm1, tm2, tm3 = args
#                 get_branch_thermal_capacity_dc_ug(ta, tm3, p1)
#             else  # dc_ss
#                 Float64(args[4])  # p1 = rvcap, no derating
#             end
#         end) => :rvcap_derated,
# )

# show(
#     filter(:investment => ==(false), filter(:active => ==(true), data["line"]))[:, [
#         :id_lin, :alias, :area_from, :area_to, :tref_peak_demand, :tref_summer, :tref_winter, :tm1_fwcap, :tm2_fwcap, :tm3_fwcap, :tm1_rvcap, :tm2_rvcap, :tm3_rvcap, :fwcap, :fwcap_peak_demand, :fwcap_derated, :rvcap, :rvcap_derated
#     ]],
#     allrows=true, allcols=true
# )
# # 15×18 DataFrame
# #  Row │ id_lin  alias                  area_from  area_to  tref_peak_demand  tref_summer  tref_winter  tm1_fwcap  tm2_fwcap  tm3_fwcap  tm1_rvcap   tm2_rvcap  tm3_rvcap  fwcap     fwcap_peak_demand  fwcap_derated  rvcap     rvcap_derated 
# #      │ Int64   String                 String     String   Float64           Float64      Float64      Float64   Float64   Float64   Float64    Float64   Float64   Float64  Float64           Float64       Float64  Float64      
# # ─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
# #    1 │      1  CQ->NQ                 QLD        QLD                  37.0         32.0         15.0   79.0769  NaN        90.0       79.0769     NaN        90.0   1400.0            1200.0      1080.88    1400.0      1080.88
# #    2 │      2  CQ->GG                 QLD        QLD                  37.0         32.0         15.0   45.6     NaN        90.0       46.7683     NaN        90.0   1050.0             700.0       630.513   1100.0       675.55
# #    3 │      3  SQ->CQ                 QLD        QLD                  37.0         32.0         15.0  NaN       NaN        90.0      NaN          NaN        90.0   1100.0            1100.0       990.807   2100.0      1891.54
# #    4 │      4  QNI North              NSW        QLD                  37.0         32.0          9.0  NaN        64.3441   64.3441  2008.26       NaN        90.0    745.0             685.0       545.55    1170.0      1085.38
# #    5 │      5  Terranora              NSW        QLD                  37.0         32.0          9.0   37.0      37.0      37.0       46.0         46.0      46.0     50.0               0.0         0.0      200.0         0.0
# #    6 │      6  QNI South              NSW        NSW                  42.0         32.0          9.0  NaN       NaN        90.0      139.108      NaN        90.0    910.0             910.0       861.301   1025.0       880.231
# #    7 │      7  CNSW->SNW North        NSW        NSW                  42.0         32.0          9.0  241.546   NaN        90.0      241.546      NaN        90.0   4730.0            4490.0      4249.72    4730.0      4249.72
# #    8 │      8  CNSW->SNW South        NSW        NSW                  42.0         32.0          9.0  188.725   NaN        90.0      188.725      NaN        90.0   2720.0            2540.0      2404.07    2720.0      2404.07
# #    9 │      9  VNI North              NSW        NSW                  42.0         32.0          9.0  150.704   NaN        90.0      125.381      NaN        90.0   2950.0            2700.0      2555.51    2590.0      2195.84
# #   10 │     10  VNI South              VIC        NSW                  41.0         32.0          8.0  NaN        69.0218   69.0218   NaN          NaN        90.0   1000.0             870.0       771.254    400.0       374.711
# #   11 │     11  Heywood                VIC        SA                   41.0         32.0          8.0  NaN       NaN        90.0      NaN          NaN        90.0    650.0             650.0       608.905    650.0       608.905
# #   12 │     12  SESA->CSA              SA         SA                   43.0         35.0         11.0  NaN       NaN        90.0      NaN          NaN        90.0    650.0             650.0       621.725    650.0       621.725
# #   13 │     13  Murraylink             VIC        SA                   41.0         32.0          8.0   46.0      46.0      46.0       46.0         46.0      46.0    220.0             220.0         0.0      200.0         0.0
# #   14 │     14  Basslink               TAS        VIC                   7.7          7.7          1.2  NaN       NaN       NaN        NaN          NaN       NaN      594.0             594.0       594.0      478.0       478.0
# #   15 │     15  Project EnergyConnect  NSW        SA                   20.0         20.0         20.0   90.0      90.0      90.0       90.0         90.0      90.0    800.0             800.0       627.011    800.0       627.011

# println("Ambient temperature = $(ta)°C:")
# show(
#     filter(:investment => ==(false), filter(:active => ==(true), data["line"]))[:, [
#         :id_lin, :alias, :tref_winter, :tref_summer, :tref_peak_demand, :tm1_fwcap, :tm2_fwcap, :tm3_fwcap, :fwcap, :fwcap_summer, :fwcap_peak_demand, :fwcap_derated,
#     ]],
#     allrows=true, allcols=true
# )

# show(
#     filter(:investment => ==(false), filter(:active => ==(true), data["line"]))[:, [
#         :id_lin, :alias, :tref_winter, :tref_summer, :tref_peak_demand, :tm1_rvcap, :tm2_rvcap, :tm3_rvcap, :rvcap, :rvcap_summer, :rvcap_peak_demand, :rvcap_derated
#     ]],
#     allrows=true, allcols=true
# )

outdir = joinpath(@__DIR__, "..", "result", "eda")
mkpath(outdir)

# Line temperature data
temerature_dir = joinpath(@__DIR__, "../..", "data/weather/temperature")
line_temperature_file_name = "Line_2m_temperature-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"
line_ta_df = CSV.read(joinpath(temerature_dir, line_temperature_file_name), DataFrame)
line_ta_df
# 9072×5 DataFrame
#   Row │ id     id_lin  scenario  date                 value   
#       │ Int64  Int64   Int64     String31             Float64 
# ──────┼───────────────────────────────────────────────────────
#     1 │     1       1         1  2030-12-21 00:00:00  29.1388
#     2 │     2       2         1  2030-12-21 00:00:00  28.7554
#     3 │     3       3         1  2030-12-21 00:00:00  29.4814
#     4 │     4       4         1  2030-12-21 00:00:00  26.9522
#     5 │     5       5         1  2030-12-21 00:00:00  26.9522
#     6 │     6       6         1  2030-12-21 00:00:00  23.5559
#     7 │     7       7         1  2030-12-21 00:00:00  21.6727
#     8 │     8       8         1  2030-12-21 00:00:00  21.6727
#     9 │     9       9         1  2030-12-21 00:00:00  26.4421
#    10 │    10      10         1  2030-12-21 00:00:00  22.9955
#   ⋮   │   ⋮      ⋮        ⋮               ⋮              ⋮
#  9063 │  9063      45         1  2030-12-27 23:00:00  16.9084
#  9064 │  9064      46         1  2030-12-27 23:00:00  16.9084
#  9065 │  9065      47         1  2030-12-27 23:00:00  16.9084
#  9066 │  9066      48         1  2030-12-27 23:00:00  16.9084
#  9067 │  9067      49         1  2030-12-27 23:00:00  16.4957
#  9068 │  9068      50         1  2030-12-27 23:00:00  16.0348
#  9069 │  9069      51         1  2030-12-27 23:00:00  16.0348
#  9070 │  9070      52         1  2030-12-27 23:00:00  16.1569
#  9071 │  9071      53         1  2030-12-27 23:00:00  16.1569
#  9072 │  9072      54         1  2030-12-27 23:00:00  20.7663
#                                              9052 rows omitted

# id_target = 13  # check Murraylink line temperature data
# line_ta_df[line_ta_df.id_lin .== id_target, :]
# maximum(line_ta_df[line_ta_df.id_lin .== id_target, :].value)

fwcap_sched = get_branch_thermal_capacity(
    line_ta_df, data["line"],
    (:tref_summer, :tref_peak_demand,
     :fwcap_summer, :fwcap_peak_demand,
     :tm2_fwcap, :tm3_fwcap);
     notconstrained_lines=forward_thermal_notconstrained
)
CSV.write(joinpath(outdir, "Line_fwcap-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), fwcap_sched)
fwcap_sched
# 9072×5 DataFrame
#   Row │ id     id_lin  scenario  date                 value    
#       │ Int64  Int64   Int64     String31             Float64  
# ──────┼────────────────────────────────────────────────────────
#     1 │     1       1         1  2030-12-21 00:00:00  1235.93
#     2 │     2       2         1  2030-12-21 00:00:00   779.039
#     3 │     3       3         1  2030-12-21 00:00:00  1100.0
#     4 │     4       4         1  2030-12-21 00:00:00   745.0
#     5 │     5       5         1  2030-12-21 00:00:00    50.0
#     6 │     6       6         1  2030-12-21 00:00:00   910.0
#     7 │     7       7         1  2030-12-21 00:00:00  4599.31
#     8 │     8       8         1  2030-12-21 00:00:00  2622.35
#     9 │     9       9         1  2030-12-21 00:00:00  2762.49
#    10 │    10      10         1  2030-12-21 00:00:00  1000.0
#   ⋮   │   ⋮      ⋮        ⋮               ⋮              ⋮
#  9063 │  9063      45         1  2030-12-27 23:00:00  2200.0
#  9064 │  9064      46         1  2030-12-27 23:00:00  2000.0
#  9065 │  9065      47         1  2030-12-27 23:00:00  6000.0
#  9066 │  9066      48         1  2030-12-27 23:00:00  3000.0
#  9067 │  9067      49         1  2030-12-27 23:00:00  1935.0
#  9068 │  9068      50         1  2030-12-27 23:00:00   750.0
#  9069 │  9069      51         1  2030-12-27 23:00:00   750.0
#  9070 │  9070      52         1  2030-12-27 23:00:00  1640.0
#  9071 │  9071      53         1  2030-12-27 23:00:00  3000.0
#  9072 │  9072      54         1  2030-12-27 23:00:00  2983.53
#                                               9052 rows omitted

rvcap_sched = get_branch_thermal_capacity(
    line_ta_df, data["line"],
    (:tref_summer, :tref_peak_demand,
     :rvcap_summer, :rvcap_peak_demand,
     :tm2_rvcap, :tm3_rvcap);
     notconstrained_lines=reverse_thermal_notconstrained
)
CSV.write(joinpath(outdir, "Line_rvcap-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), rvcap_sched)
rvcap_sched
# 9072×5 DataFrame
#   Row │ id     id_lin  scenario  date                 value    
#       │ Int64  Int64   Int64     String31             Float64  
# ──────┼────────────────────────────────────────────────────────
#     1 │     1       1         1  2030-12-21 00:00:00  1235.93
#     2 │     2       2         1  2030-12-21 00:00:00   828.3
#     3 │     3       3         1  2030-12-21 00:00:00  2100.0
#     4 │     4       4         1  2030-12-21 00:00:00  1164.74
#     5 │     5       5         1  2030-12-21 00:00:00   200.0
#     6 │     6       6         1  2030-12-21 00:00:00   965.964
#     7 │     7       7         1  2030-12-21 00:00:00  4599.31
#     8 │     8       8         1  2030-12-21 00:00:00  2622.35
#     9 │     9       9         1  2030-12-21 00:00:00  2388.04
#    10 │    10      10         1  2030-12-21 00:00:00   400.0
#   ⋮   │   ⋮      ⋮        ⋮               ⋮              ⋮
#  9063 │  9063      45         1  2030-12-27 23:00:00  2200.0
#  9064 │  9064      46         1  2030-12-27 23:00:00  2000.0
#  9065 │  9065      47         1  2030-12-27 23:00:00  6000.0
#  9066 │  9066      48         1  2030-12-27 23:00:00  3000.0
#  9067 │  9067      49         1  2030-12-27 23:00:00  1669.0
#  9068 │  9068      50         1  2030-12-27 23:00:00   750.0
#  9069 │  9069      51         1  2030-12-27 23:00:00   750.0
#  9070 │  9070      52         1  2030-12-27 23:00:00  1640.0
#  9071 │  9071      53         1  2030-12-27 23:00:00  3000.0
#  9072 │  9072      54         1  2030-12-27 23:00:00  2983.53
#                                               9052 rows omitted

# Generator temperature data
# TODO: generator 23 missing, RoR
temerature_dir = joinpath(@__DIR__, "../..", "data/weather/temperature")
generator_temperature_file_name = "Generator_2m_temperature-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"

generator_ta_df = CSV.read(joinpath(temerature_dir, generator_temperature_file_name), DataFrame)
generator_ta_df

# Add area data to generator DataFrame for temperature-based derating and analysis
add_data_col_by_id!(data["generator"], SiennaNEM.area_to_tref_peak_demand; data_col=:tref_peak_demand)
add_data_col_by_id!(data["generator"], SiennaNEM.area_to_tref_summer; data_col=:tref_summer)
add_data_col_by_id!(data["generator"], SiennaNEM.area_to_tref_winter; data_col=:tref_winter)

# Wind turbine temperature capacity correction factor (CF) (per-unit), piecewise-flat
"""
    get_wind_thermal_correction_factor(
        ta_df,
        gen_df;
        id_col=:id,
        gen_id_col=:id_gen,
        altitude_col=nothing,              # e.g. :tower_base_alt_masl if present in gen_df
        t_no_derate_c=30.0,
        t_region2_end_c=40.0,
        t_stop_c=45.0,
        dcf_dt_region2=-0.00909,
        dcf_dt_region3=-0.10909,
        altitude_stop_threshold_masl=500.0,
        tower_base_alt_masl_default=0.0,
        t2m_to_ambient_shift_c=-1.0,
    ) -> DataFrame

DataFrame version of the wind-turbine temperature correction factor (per-unit), piecewise-linear.

This correction factor can be applied to wind generator capacity, not power output.

Assumes `ta_df` and `gen_df` are already restricted to wind generators (filter outside).

The correction factor at the Region 2/3 boundary is always derived from `dcf_dt_region2`,
ensuring internal consistency.

Regions (let `t = t2m + t2m_to_ambient_shift_c`):

Normal altitude (`alt ≤ altitude_stop_threshold_masl`):
- `t <  t_no_derate_c`                     -> `cf = 1.0`
- `t_no_derate_c  ≤ t <  t_region2_end_c`  -> `cf = 1.0 + dcf_dt_region2 * (t - t_no_derate_c)`
- `t_region2_end_c ≤ t ≤ t_stop_c`         -> `cf = cf_region2_end + dcf_dt_region3 * (t - t_region2_end_c)`
                                               where `cf_region2_end = 1.0 + dcf_dt_region2 * (t_region2_end_c - t_no_derate_c)`
- `t >  t_stop_c`                           -> `cf = 0.0`

High altitude (`alt > altitude_stop_threshold_masl`):
- `t <  t_no_derate_c`                     -> `cf = 1.0`
- `t_no_derate_c  ≤ t ≤ t_region2_end_c`   -> `cf = 1.0 + dcf_dt_region2 * (t - t_no_derate_c)`
- `t >  t_region2_end_c`                    -> `cf = 0.0`

Missing/unusable temperatures return `NaN` CF.

Usage:

    min(cf * gen_capacity, power_output)
"""
function get_wind_thermal_correction_factor(
    ta_df::DataFrame,
    gen_df::DataFrame;
    id_col::Symbol = :id,
    gen_id_col::Symbol = :id_gen,
    altitude_col = nothing,
    t_no_derate_c::Real = 30.0,
    t_region2_end_c::Real = 40.0,
    t_stop_c::Real = 45.0,
    dcf_dt_region2::Real = -0.00909,
    dcf_dt_region3::Real = -0.10909,
    altitude_stop_threshold_masl::Real = 500.0,
    tower_base_alt_masl_default::Real = 0.0,
    t2m_to_ambient_shift_c::Real = -1.0,
)
    # Missing-safe scalar kernel
    @inline function _wind_cf_scalar(t2m_c, tower_base_alt_masl)::Float64
        ismissing(t2m_c) && return 1.0

        t2m = Float64(t2m_c)
        isfinite(t2m) || return 1.0

        ismissing(tower_base_alt_masl) && return NaN

        t = t2m + Float64(t2m_to_ambient_shift_c)

        t_no = Float64(t_no_derate_c)
        t_r2 = Float64(t_region2_end_c)
        t_st = Float64(t_stop_c)

        # Boundary value, used only in the normal-altitude Region 3
        cf_r2_end = 1.0 + Float64(dcf_dt_region2) * (t_r2 - t_no)

        high_alt = Float64(tower_base_alt_masl) > Float64(altitude_stop_threshold_masl)

        if high_alt
            # High altitude: stop once above region 2 end
            # Note: boundary at t_r2 is inclusive (<=) here,
            # unlike the normal-altitude branch (<), so cf is continuous at the boundary.
            if t < t_no
                return 1.0
            elseif t <= t_r2
                return 1.0 + Float64(dcf_dt_region2) * (t - t_no)
            else
                return 0.0
            end
        else
            # Normal altitude: three regions + stop
            if t < t_no
                return 1.0
            elseif t < t_r2
                # Region 2: linear derate begins
                return 1.0 + Float64(dcf_dt_region2) * (t - t_no)
            elseif t <= t_st
                # Region 3: steeper linear derate, anchored to the computed boundary value
                return cf_r2_end + Float64(dcf_dt_region3) * (t - t_r2)
            else
                # Region 4: full stop
                return 0.0
            end
        end
    end

    df = leftjoin(ta_df, gen_df; on=gen_id_col)

    use_altitude = (altitude_col isa Symbol) && (altitude_col in names(df))
    altvec = if use_altitude
        # if altitude exists but has missings, fall back to default
        something.(df[!, altitude_col], Float64(tower_base_alt_masl_default))
    else
        fill(Float64(tower_base_alt_masl_default), nrow(df))
    end

    df[!, :value] = _wind_cf_scalar.(df[!, :value], altvec)

    return select(df, id_col, gen_id_col, :scenario, :date, :value)
end

wind_tech_values = ("Wind",)
gen_wind_df = filter(:tech => t -> !ismissing(t) && (t in wind_tech_values), data["generator"])

wind_id_gens = Set(gen_wind_df[!, :id_gen])
ta_wind_df = filter(:id_gen => idg -> idg in wind_id_gens, generator_ta_df)

windcf_sched = get_wind_thermal_correction_factor(
    ta_wind_df, gen_wind_df;
    gen_id_col=:id_gen,
    altitude_col=nothing,
)
CSV.write(joinpath(outdir, "Generator_cf_wind-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), windcf_sched)
windcf_sched

# We can see here that lots of wind became 0
# 1-minimum(windcf_sched[:, :value]) * 100

# windpmax_filtered = filter(:id_gen => idg -> idg in wind_id_gens, data["generator_pmax_ts"])
# dt_start = DateTime("2038-01-23 00:00:00", "yyyy-mm-dd HH:MM:SS")
# dt_end   = DateTime("2038-01-25 00:00:00", "yyyy-mm-dd HH:MM:SS")
# windpmax_filtered = filter(:date => d -> dt_start <= d <= dt_end, windpmax_filtered)

# Photovoltaic temperature power output correction factor (CF) (per-unit), piecewise-flat
"""
    get_inverter_thermal_correction_factor(
        ta_df,
        gen_df;
        id_col=:id,
        gen_id_col=:id_gen,
        t2m_to_ambient_shift_c=-10.0,
        cooling_dT=0.0,
        T_derate_start=50.0,
        T_cutoff=60.0,
    ) -> DataFrame

Inverter thermal derating CF (per-unit), piecewise-linear in ambient temperature.

Let `T_amb = t2m + t2m_to_ambient_shift_c`.
Let `T_start = T_derate_start + cooling_dT`, `T_cut = T_cutoff + cooling_dT`.

    cf_inv = 1.0                                 if T_amb ≤ T_start
           = (T_cut - T_amb) / (T_cut - T_start) if T_start < T_amb < T_cut
           = 0.0                                 if T_amb ≥ T_cut

Guards:
- If `T_cut ≤ T_start` returns `NaN` for all rows (invalid thresholds).
- Missing/unusable temperatures return `NaN`.

Returns `:id, :id_gen, :scenario, :date, :value` with `:value = cf_inv`.
"""
function get_inverter_thermal_correction_factor(
    ta_df::DataFrame,
    gen_df::DataFrame;
    id_col::Symbol = :id,
    gen_id_col::Symbol = :id_gen,
    t2m_to_ambient_shift_c::Real = -10.0,
    cooling_dT::Real = 0.0,
    T_derate_start::Real = 50.0,
    T_cutoff::Real = 60.0,
)
    T_start = Float64(T_derate_start) + Float64(cooling_dT)
    T_cut = Float64(T_cutoff) + Float64(cooling_dT)
    ΔT = T_cut - T_start

    @inline function _inv_cf_scalar(t2m_c)::Float64
        ismissing(t2m_c) && return 1.0
        ΔT > 0.0 || return NaN

        t2m = Float64(t2m_c)
        isfinite(t2m) || return 1.0

        T_amb = t2m + Float64(t2m_to_ambient_shift_c)

        if T_amb <= T_start
            return 1.0
        elseif T_amb >= T_cut
            return 0.0
        else
            return (T_cut - T_amb) / ΔT
        end
    end

    df = leftjoin(ta_df, gen_df; on=gen_id_col)
    df[!, :value] = _inv_cf_scalar.(df[!, :value])
    return select(df, id_col, gen_id_col, :scenario, :date, :value)
end

"""
    get_pv_module_temperature_correction_factor_conservative(
        ta_df,
        gen_df;
        id_col=:id,
        gen_id_col=:id_gen,
        t2m_to_ambient_shift_c=0.0,
        beta=-0.0036,
        G_poa_wm2=1000.0,
        v_wind_ms=1.0,
        U0=25.0,
        U1=6.84,
    ) -> DataFrame

PV module temperature derating CF (per-unit): Faiman (2008) + linear β.

This function assumes that the it will be multiplied with pv module power output
that is not already derated for temperature. Thus, the usage is:

    power_output_derated = cf * power_output

Let `T_amb = t2m + t2m_to_ambient_shift_c`.

    T_cell   = T_amb + G / (U0 + U1*v_wind)
    cf_mod   = 1 + beta*(T_cell - 25)

Guards:
- If `U0 + U1*v_wind ≤ 0` returns `NaN`.
- Missing/unusable temperatures return `NaN`.

Returns `:id, :id_gen, :scenario, :date, :value` with `:value = cf_module`.
"""
function get_pv_module_temperature_correction_factor_conservative(
    ta_df::DataFrame,
    gen_df::DataFrame;
    id_col::Symbol = :id,
    gen_id_col::Symbol = :id_gen,
    t2m_to_ambient_shift_c::Real = 0.0,
    beta::Real = -0.0036,
    G_poa_wm2::Real = 1000.0,
    v_wind_ms::Real = 1.0,
    U0::Real = 25.0,
    U1::Real = 6.84,
)
    denom = Float64(U0) + Float64(U1) * Float64(v_wind_ms)

    @inline function _pv_mod_cf_scalar(t2m_c)::Float64
        ismissing(t2m_c) && return 1.0
        denom > 0.0 || return NaN

        t2m = Float64(t2m_c)
        isfinite(t2m) || return 1.0

        T_amb = t2m + Float64(t2m_to_ambient_shift_c)
        T_cell = T_amb + Float64(G_poa_wm2) / denom

        return 1.0 + Float64(beta) * (T_cell - 25.0)
    end

    df = leftjoin(ta_df, gen_df; on=gen_id_col)
    df[!, :value] = _pv_mod_cf_scalar.(df[!, :value])
    return select(df, id_col, gen_id_col, :scenario, :date, :value)
end

"""
    get_pv_module_temperature_correction_factor_nonconservative(
        ta_df,
        gen_df;
        id_col=:id,
        gen_id_col=:id_gen,
        tref_col=:tref_peak_demand,
        t2m_to_ambient_shift_c=0.0,
        beta=-0.0024,
        G_poa_wm2=1000.0,
        v_wind_ms=1.0,
        U0=25.0,
        U1=6.84,
    ) -> DataFrame

PV module temperature correction factor (per-unit) relative to a baseline where
power is already derated at `T_ref = gen_df[tref_col]` for each generator.

Returned `:value` is:

- `1.0` when `T_amb ≤ T_ref`
- `cf_increase * cf_decrease` when `T_amb > T_ref`, where:

    cf_at_ref   = 1 + beta*(T_cell(T_ref) - 25)
    cf_increase = 1 / cf_at_ref
    cf_decrease = 1 + beta*(T_cell(T_amb) - 25)

So:
    power_output_derated_at_ref * (returned_cf) = power_output_derated_at_ref * (cf(T_amb) / cf(T_ref))

This function assumes that the it will be multiplied with pv module power output
that is already derated for temperature. Thus, the usage is:

    power_output_derated = cf * power_output_derated_at_ref

beta :
    Power temperature coefficient [/°C], dimensionless.
    Default -0.0024 (-0.24 %/°C), representative of monocrystalline PERC.

    Typical values by technology (IEC 61853-1:2011 measurement method;
    values from commercial module datasheets 2020–2024):
        • Mono PERC (e.g. LONGi LR5-72HPH, JA Solar JAM72S30):  -0.0034 to -0.0037
        • TOPCon   (e.g. LONGi Hi-MO 9, Jinko Tiger Neo 78HL4):  -0.0028 to -0.0030
        • HJT/SHJ  (e.g. REC Alpha Pure-R, Panasonic EverVolt):  -0.0024 to -0.0026
        • CdTe     (First Solar Series 6 / Series 7 datasheet):   -0.0028
        • CPV      (Spectrolab, Azur Space — concentrator cells): -0.0050 to -0.0060

    ⚠ Criticism: β is treated as constant here, but it has a weak
    irradiance dependence (≈+0.01 %/°C per decade of G reduction) and
    increases slightly with module aging.  For most energy yield studies
    the error is under 0.5 %, but high-precision bankable yield
    assessments should use the irradiance-dependent β matrix from
    IEC 61853-1 Table 1 measurements.

Guards:
- Missing/unusable temperatures return `NaN`.
- Missing `T_ref` returns `NaN`.
- If `U0 + U1*v_wind ≤ 0` returns `NaN`.
- If `cf_at_ref == 0` returns `NaN` (avoid division-by-zero).

Returns `:id, :id_gen, :scenario, :date, :value`.
"""
function get_pv_module_temperature_correction_factor_nonconservative(
    ta_df::DataFrame,
    gen_df::DataFrame;
    id_col::Symbol = :id,
    gen_id_col::Symbol = :id_gen,
    tref_col::Symbol = :tref_summer,
    t2m_to_ambient_shift_c::Real = 0.0,
    beta::Real = -0.0036,
    G_poa_wm2::Real = 1000.0,  # TODO: consider use actual solar irradiance, support historical and future solar.
    v_wind_ms::Real = 1.0,
    U0::Real = 25.0,
    U1::Real = 6.84,
)
    denom = Float64(U0) + Float64(U1) * Float64(v_wind_ms)

    @inline function _cf_mod_rel_scalar(t2m_c, tref_c)::Float64
        ismissing(t2m_c) && return 1.0
        ismissing(tref_c) && return NaN
        denom > 0.0 || return NaN

        t2m = Float64(t2m_c)
        isfinite(t2m) || return 1.0

        T_ref = Float64(tref_c)
        isfinite(T_ref) || return NaN

        T_amb = t2m + Float64(t2m_to_ambient_shift_c)

        # return 1 below/at baseline
        if T_amb <= T_ref
            return 1.0
        end

        # cf(T_ref)
        T_cell_ref = T_ref + Float64(G_poa_wm2) / denom
        cf_at_ref = 1.0 + Float64(beta) * (T_cell_ref - 25.0)
        cf_at_ref == 0.0 && return NaN

        cf_increase = 1.0 / cf_at_ref

        # cf(T_amb)
        T_cell = T_amb + Float64(G_poa_wm2) / denom
        cf_decrease = 1.0 + Float64(beta) * (T_cell - 25.0)

        return cf_increase * cf_decrease
    end

    df = leftjoin(ta_df, gen_df; on=gen_id_col)
    df[!, :value] = _cf_mod_rel_scalar.(df[!, :value], df[!, tref_col])

    return select(df, id_col, gen_id_col, :scenario, :date, :value)
end

# LargePV (grid_open_rack: U0=25, U1=6.84; central inverter 50→60)
largepv_tech_values = ("LargePV",)
gen_largepv_df = filter(:tech => t -> !ismissing(t) && (t in largepv_tech_values), data["generator"])

largepv_id_gens = Set(gen_largepv_df[!, :id_gen])
ta_largepv_df = filter(:id_gen => idg -> idg in largepv_id_gens, generator_ta_df)

pvmodcf_largepv_sched = get_pv_module_temperature_correction_factor_nonconservative(
    ta_largepv_df, gen_largepv_df;
    gen_id_col=:id_gen,
    U0=25.0, U1=6.84,
)
pvinvcf_largepv_sched = get_inverter_thermal_correction_factor(
    ta_largepv_df, gen_largepv_df;
    gen_id_col=:id_gen,
    T_derate_start=50.0, T_cutoff=60.0,
    cooling_dT=0.0,
)
CSV.write(joinpath(outdir, "Generator_cf_largepv_pvmod-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), pvmodcf_largepv_sched)
CSV.write(joinpath(outdir, "Generator_cf_largepv_pvinv-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), pvinvcf_largepv_sched)

# RoofPV (rooftop_flush: U0=20, U1=0; string inverter 40→55)
roofpv_tech_values = ("RoofPV",)
gen_roofpv_df = filter(:tech => t -> !ismissing(t) && (t in roofpv_tech_values), data["generator"])

roofpv_id_gens = Set(gen_roofpv_df[!, :id_gen])
ta_roofpv_df = filter(:id_gen => idg -> idg in roofpv_id_gens, generator_ta_df)

pvmodcf_roofpv_sched = get_pv_module_temperature_correction_factor_nonconservative(
    ta_roofpv_df, gen_roofpv_df;
    gen_id_col=:id_gen,
    U0=20.0, U1=0.0,
)
pvinvcf_roofpv_sched = get_inverter_thermal_correction_factor(
    ta_roofpv_df, gen_roofpv_df;
    gen_id_col=:id_gen,
    T_derate_start=40.0, T_cutoff=55.0,
    cooling_dT=0.0,
)
CSV.write(joinpath(outdir, "Generator_cf_roofpv_pvmod-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), pvmodcf_roofpv_sched)
CSV.write(joinpath(outdir, "Generator_cf_roofpv_pvinv-method$(method_number)-$(date_start)_$(date_end)-era5shape$(era5_date)_$(window_name)_AEST_sched_.csv"), pvinvcf_roofpv_sched)

# # For assumed ISP already derated
# julia> 1-minimum(pvmodcf_largepv_sched[:, :value]) * 100
# 5.994533452480866
# julia> 1-minimum(pvmodcf_roofpv_sched[:, :value]) * 100
# 6.499367547383172

# # For assumed ISP not yet derated
# julia> 1-minimum(pvmodcf_roofpv_sched[:, :value]) * 100
# 25.68569732666015
# julia> 1-minimum(pvmodcf_largepv_sched[:, :value]) * 100
# 18.99222998997674
