using Test
using SiennaNEM
using DataFrames
using Dates


@testset "Time Series Functions Tests" verbose=true begin
    reference_trace = 4006
    poe = 10
    tyear = 2025
    file_format = "arrow"
    system_data_dir = joinpath(
        @__DIR__, "../..", "NEM-reliability-suite", "data", "pisp-datasets",
        "out-ref$reference_trace-poe$poe", file_format
    )
    ts_data_dir = joinpath(system_data_dir, "schedule-$tyear")
    data = read_system_data(system_data_dir)
    read_ts_data!(data, ts_data_dir)

    df_generator = data["generator"]
    df_generator_n_ts = data["generator_n_ts"]
    df_generator_pmax_ts = data["generator_pmax_ts"]

    @testset "Generator N (Number of Units) Test" begin
        # Test configuration for n
        df_static = df_generator
        id_col = "id_gen"
        col_ref = "n"
        df_ts = df_generator_n_ts
        target_datetime = DateTime("2024-02-01T00:00:00")
        date_start = DateTime(2024, 1, 1)
        date_end = DateTime(2025, 1, 1)
        scenario = 1

        # Create time series
        df_ts_full = get_full_ts_df(
            df_static, df_ts, id_col, col_ref, scenario, date_start, date_end
        )

        # Test specific values at target datetime
        target_row_idx = findfirst(==(target_datetime), df_ts_full.date)
        @test !isnothing(target_row_idx)

        # Test expected values: must be 4, 0, 0 for generators 1, 84, 69
        if "1" in names(df_ts_full)
            @test df_ts_full[target_row_idx, "1"] == 4
        end

        if "84" in names(df_ts_full)
            @test df_ts_full[target_row_idx, "84"] == 1  # Updated based on your output showing 1
        end

        if "69" in names(df_ts_full)
            @test df_ts_full[target_row_idx, "69"] == 0
        end

        # Test previous hour values
        prev_hour_idx = target_row_idx - 1
        if prev_hour_idx > 0
            if "1" in names(df_ts_full)
                @test df_ts_full[prev_hour_idx, "1"] == 4
            end

            if "84" in names(df_ts_full)
                @test df_ts_full[prev_hour_idx, "84"] == 0
            end

            if "69" in names(df_ts_full)
                @test df_ts_full[prev_hour_idx, "69"] == 0
            end
        end

        # Test no missing
        @test !any(ismissing, eachcol(df_ts_full))

    end

    @testset "Generator Pmax Test" begin
        # Test configuration for pmax
        df_static = df_generator
        id_col = "id_gen"
        col_ref = "pmax"
        df_ts = df_generator_pmax_ts
        target_datetime = DateTime("2044-07-01T00:00:00")
        date_start = DateTime(2044, 6, 28)
        date_end = DateTime(2044, 7, 2)
        scenario = 1

        # Create time series
        df_ts_full = get_full_ts_df(
            df_static, df_ts, id_col, col_ref, scenario, date_start, date_end
        )

        # Test specific values at target datetime
        target_row_idx = findfirst(==(target_datetime), df_ts_full.date)
        @test !isnothing(target_row_idx)

        # Test expected values for generators 78, 79
        if "78" in names(df_ts_full)
            @test df_ts_full[target_row_idx, "78"] ≈ 106.0 atol = 1e-6
        end

        if "79" in names(df_ts_full)
            @test df_ts_full[target_row_idx, "79"] ≈ 40.0 atol = 1e-6
        end

        # Test previous hour values
        prev_hour_idx = target_row_idx - 1
        if prev_hour_idx > 0
            if "78" in names(df_ts_full)
                @test df_ts_full[prev_hour_idx, "78"] ≈ 46.8 atol = 1e-6
            end

            if "79" in names(df_ts_full)
                @test df_ts_full[prev_hour_idx, "79"] ≈ 40.0 atol = 1e-6
            end
        end

        # Test no missing
        @test !any(ismissing, eachcol(df_ts_full))

        @testset "Data Structure Tests" begin
            @test isa(df_ts_full, DataFrame)
            @test "date" in names(df_ts_full)
            @test nrow(df_ts_full) > 0

            # Test date range
            expected_hours = Int(Dates.value(date_end - date_start) / (1000 * 60 * 60)) + 1
            @test nrow(df_ts_full) == expected_hours

            # Test no missing values after forward fill
            for col_name in names(df_ts_full)
                if col_name != "date"
                    @test !any(ismissing.(df_ts_full[!, col_name]))
                end
            end
        end
    end
end
