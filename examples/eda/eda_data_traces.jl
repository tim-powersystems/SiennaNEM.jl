# unique(data["generator"][:, :fuel])
# 7-element Vector{String}:
#  "Coal"
#  "Diesel"
#  "Hydro"
#  "Hydrogen"
#  "Natural Gas"
#  "Solar"
#  "Wind"

df_gen_re = filter(:fuel => in(["Solar", "Wind"]), data["generator"])
df_gen_re_pmax_ts = filter(:id_gen => in(df_gen_re[:, :id_gen]), data["generator_pmax_ts"])

gen_id = 92
pmax = only(filter(:id_gen => ==(gen_id), df_gen_re)[:, :pmax])  # 100
vmax = maximum(filter(:id_gen => ==(gen_id), df_gen_re_pmax_ts)[:, :value])  # 989.8632
println("gen_id=$(gen_id): pmax=$(pmax), vmax=$(vmax), vmax < pmax => ", isless(vmax, pmax))
# NOTE: we can see that the trace maximum value (vmax) is much higher than the pmax in
# the system data, because the system data `pmax` is a dummy value for RE components.
# This will be "fixed" by SiennaNEM.read_data.update_system_data_bound!


# plot demands
re_ids = Set(df_gen_re[:, :id_gen])
vre_ts = filter(:id_gen => in(re_ids), data["generator_pmax_ts"])

plts = map(1:3) do scen
    d = filter(:scenario => ==(scen), data["demand_l_ts"])
    v = filter(:scenario => ==(scen), vre_ts)

    d_sum = combine(groupby(d, :date), :value => sum => :total)
    v_sum = combine(groupby(v, :date), :value => sum => :total)

    p = plot(title = "Scenario $scen", xlabel = "Time", ylabel = "Value")
    plot!(p, d_sum[:, :date], d_sum[:, :total], label = "Demand", color = :steelblue)
    plot!(p, v_sum[:, :date], v_sum[:, :total], label = "VRE", color = :orange)
    p
end

plot(plts..., layout = (3, 1), size = (900, 900))
