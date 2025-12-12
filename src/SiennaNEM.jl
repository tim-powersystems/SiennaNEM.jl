module SiennaNEM

    using DataFrames, Dates, TimeSeries, OrderedCollections
    using CSV, Arrow
    using PlotlyJS
    using InfrastructureSystems, PowerSimulations, PowerSystems

    const IS = InfrastructureSystems
    const PS = PowerSimulations
    const PSY = PowerSystems
    const DF = DataFrames

    include("add_ts.jl")
    include("const.jl")
    include("create_system.jl")
    include("export.jl")
    include("plot.jl")
    include("read_data.jl")
    include("run.jl")
    include("utils.jl")

    include("problem/uc.jl")
    include("dev/forward_fill_sched.jl")

    # Environment variables for configuration
    const ENV_HYDRORES_AS_THERMAL = true
    const ENV_HYDROPUMP_AS_BATTERY = true

    # Exported functions and constants
    export get_data, read_system_data, read_ts_data!, preprocess_date!
    export update_system_data_bound!, add_area_df!, add_maps!
    export add_fuel_col!, add_primemover_col!, add_datatype_col!, add_id_area_col!
    export extend_generator_data, get_group_max
    export clean_ts_data!
    export create_system!, add_ts!
    export tech_to_primemover, tech_to_datatype, tech_to_fuel
    export area_to_name
    export get_flat_generators, get_generator_units, count_all_generators
    export groupbyd, groupby_scenario_at_init_day, groupby_scenario_at_day
    export filter_value_from_df, filter_values_from_df
    export add_sts!, add_st!
    export get_specific_scenario_from_df, get_time_slice, get_time_slices_iterator
    export diff_df, show_parameter, sort_res_cols
    export get_map_from_df, get_grouped_map_from_df, get_inverse_map
    export get_bus_to_gen, get_gen_to_bus, get_col_to_group, get_group_to_col
    export sum_by_group, get_component_columns
    export get_full_ts_df, add_tsf_data!
    export plot_stacked

    export build_problem_base_uc
    export run_decision_model, run_decision_model_loop

    export export_optimization_results_to_csv, get_problem_results

end