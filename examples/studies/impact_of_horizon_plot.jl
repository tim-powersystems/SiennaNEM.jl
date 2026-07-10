using PlotlyJS

# Create bus ID to name mapping
bus_to_name = get_map_from_df(data["bus"], :id_bus, :name)

# Define plot configurations: (data_key, id_map, title, ylabel)
plot_staged_list = [
    # data_key, id_map, title, ylabel
    ("bus_tgen_pg", bus_to_name, :bus, "Thermal Generator Output by Bus", "Power (MW)"),
    ("bus_gen_pg", bus_to_name, :bus, "Generation by Bus", "Power (MW)"),
    ("bus_vre_pc", bus_to_name, :bus, "Power Curtailment by Bus", "Power (MW)"),
    # ("bus_gen_pfr", bus_to_name, :bus, "Primary Frequency Response Reserve by Bus", "Reserve Capacity (MW)"),
    ("area_tgen_pg", bus_to_name, :area, "Thermal Generator Output by Area", "Power (MW)"),
    ("area_gen_pg", area_to_name, :area, "Generation by Area", "Power (MW)"),
    ("area_vre_pc", bus_to_name, :area, "Area Curtailment by Bus", "Power (MW)"),
    # ("area_gen_pfr", area_to_name, :area, "Primary Frequency Response Reserve by Area", "Reserve Capacity (MW)"),
    ("bus_ess_e", bus_to_name, :bus, "Battery Energy by Bus", "Energy (MWh)"),
    ("bus_ess_ch", bus_to_name, :bus, "Battery Charging by Bus", "Power (MW)"),
    ("bus_ess_dch", bus_to_name, :bus, "Battery Discharging by Bus", "Power (MW)"),
    ("bus_ess_chdch", bus_to_name, :bus, "Battery Charging and Discharging by Bus", "Power (MW)"),
    ("area_ess_e", area_to_name, :area, "Battery Energy by Area", "Energy (MWh)"),
    ("area_ess_ch", area_to_name, :area, "Battery Charging by Area", "Power (MW)"),
    ("area_ess_dch", area_to_name, :area, "Battery Discharging by Area", "Power (MW)"),
    ("area_ess_chdch", area_to_name, :area, "Battery Charging and Discharging by Area", "Power (MW)"),
]

# Generate all plots
# dfs_res_post = results_post["72_rolling"]  # example for 72_rolling scenario
# dfs_res_post = results_post["24"]  # example for 72_rolling scenario

for (k, dfs_res_post) in results_post

    plots_dir = "examples/result/studies/impact_of_horizon/plots/$(k)"
    mkpath(plots_dir)
    for (data_key, id_map, namecol, title, ylabel) in plot_staged_list
        p = plot_stacked_long(
            dfs_res_post[data_key],
            id_map;
            timecol=:DateTime,
            namecol=namecol,
            title=title,
            yaxis_title=ylabel,
        )
        # Use same naming convention as CSV: prefix_category_name.extension
        filename = "$(schedule_name)_scenario-$(scenario)_$(data_key).png"
        filepath = joinpath(plots_dir, filename)
        savefig(p, filepath)
        println("✓ Saved: $filepath")
    end

end
