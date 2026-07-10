using PlotlyJS

# Create bus ID to name mapping
bus_to_name = get_map_from_df(data["bus"], :id_bus, :name)

# Create output directory for plots
plots_dir = "examples/result/nem12/plots/$(schedule_name)/scenario-$(scenario)"
mkpath(plots_dir)

# Define plot configurations: (data_key, id_map, title, ylabel)
plot_staged_list = [
    # data_key, id_map, title, ylabel
    ("bus_gen_pg", bus_to_name, "Generation by Bus", "Power (MW)"),
    ("bus_tgen_pfr", bus_to_name, "Primary Frequency Response Reserve by Bus", "Reserve Capacity (MW)"),
    ("area_gen_pg", area_to_name, "Generation by Area", "Power (MW)"),
    ("area_tgen_pfr", area_to_name, "Primary Frequency Response Reserve by Area", "Reserve Capacity (MW)"),
    ("bus_ess_e", bus_to_name, "Battery Energy by Bus", "Energy (MWh)"),
    ("bus_ess_ch", bus_to_name, "Battery Charging by Bus", "Power (MW)"),
    ("bus_ess_dch", bus_to_name, "Battery Discharging by Bus", "Power (MW)"),
    ("bus_ess_chdch", bus_to_name, "Battery Charging and Discharging by Bus", "Power (MW)"),
    ("area_ess_e", area_to_name, "Battery Energy by Area", "Energy (MWh)"),
    ("area_ess_ch", area_to_name, "Battery Charging by Area", "Power (MW)"),
    ("area_ess_dch", area_to_name, "Battery Discharging by Area", "Power (MW)"),
    ("area_ess_chdch", area_to_name, "Battery Charging and Discharging by Area", "Power (MW)"),
]

# Generate all plots
for (data_key, id_map, title, ylabel) in plot_staged_list
    println(data_key)
    p = plot_stacked(
        dfs_res["post"][data_key],
        id_map;
        timecol=:DateTime,
        title=title,
        yaxis_title=ylabel,
    )
    
    # Use same naming convention as CSV: prefix_category_name.extension
    filename = "$(schedule_name)_scenario-$(scenario)_$(data_key).png"
    filepath = joinpath(plots_dir, filename)
    savefig(p, filepath)
    println("✓ Saved: $filepath")
end

# plots_dir = "examples/result/studies/impact_of_horizon/plots/$(k)"
# mkpath(plots_dir)
# for (data_key, id_map, namecol, title, ylabel) in plot_staged_list
#     # Use same naming convention as CSV: prefix_category_name.extension
#     filename = "$(schedule_name)_scenario-$(scenario)_$(data_key).png"
#     filepath = joinpath(plots_dir, filename)
#     savefig(p, filepath)
#     println("✓ Saved: $filepath")
# end
