using XLSX
using DataFrames  # For working with tables

# Construct the relative path to the Excel file
pisp_downloads_dir = joinpath(
    @__DIR__, "../../../NEM-reliability-suite/data/pisp-downloads"
)
excel_file_path = joinpath(
    pisp_downloads_dir, "2024-isp-inputs-and-assumptions-workbook.xlsx"
)

# Extract storage cost data from "Build costs" sheet
storage_cost_data = XLSX.openxlsx(excel_file_path) do wb
    sheet = wb["Build costs"]
    sheet["B23:D26"]  # Extract the range B23:D26
end

# Extract economic life data from "Lead time and project life" sheet
economic_life_data = XLSX.openxlsx(excel_file_path) do wb
    sheet = wb["Lead time and project life"]
    sheet["B15:G18"]  # Extract the range B15:G18
end

# Combine the data into a single DataFrame
combined_data = DataFrame(
    StorageType = [row[1] for row in eachrow(storage_cost_data)],  # Extract storage type from column 1
    CapitalCost = [row[3] for row in eachrow(storage_cost_data)],  # Extract capital cost from column 3
    EconomicLife = [row[6] for row in eachrow(economic_life_data)]  # Extract economic life from column 6
)

# Print the combined DataFrame
println(combined_data)
