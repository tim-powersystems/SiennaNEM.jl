using HydroPowerSimulations
using StorageSystemsSimulations
using PowerModels


function _device_type_from_model(::DeviceModel{D}) where {D}
    return D
end

function normalize_template_branch_keys!(template::ProblemTemplate)
    bad_keys = [
        k for k in keys(template.branches)
        if occursin(".", String(k))
    ]

    if isempty(bad_keys)
        return template
    end

    @warn "Detected namespaced branch model keys in template.branches; normalizing before returning template" bad_keys

    fixed = Dict{Symbol, DeviceModel{<:Branch}}()

    for (old_key, model) in template.branches
        device_type = _device_type_from_model(model)
        new_key = nameof(device_type)

        if haskey(fixed, new_key)
            error("""
            Duplicate branch model key after normalization.

            Existing normalized key:
                $new_key

            Current old key:
                $old_key

            All old branch keys:
                $(collect(keys(template.branches)))
            """)
        end

        fixed[new_key] = model
    end

    empty!(template.branches)

    for (k, v) in fixed
        template.branches[k] = v
    end

    @warn "Normalized template.branches keys" normalized_keys = collect(keys(template.branches))

    return template
end

function build_problem_base_uc(;network_model=NFAPowerModel)
    # NOTE:
    # The network_model can be from PowerModels or PowerSimulations. Examples:
    # 
    #   CopperPlatePowerModel,
    #   PTDFPowerModel,

    template_uc = ProblemTemplate()
    set_device_model!(template_uc, MonitoredLine, StaticBranchBounds)
    set_device_model!(template_uc, Line, StaticBranch)
    set_device_model!(template_uc, ThermalStandard, ThermalStandardUnitCommitment)
    set_device_model!(template_uc, RenewableDispatch, RenewableFullDispatch)
    set_device_model!(template_uc, RenewableNonDispatch, FixedOutput)
    set_device_model!(template_uc, PowerLoad, StaticPowerLoad)

    # storage
    storage_model = DeviceModel(
        EnergyReservoirStorage,
        StorageDispatchWithReserves;
        attributes=Dict(
            "reservation" => true,
            "energy_target" => false,  # bug in Sienna as it is a weak constraint
            "cycling_limits" => false,
            "regularization" => false,
        ),
        use_slacks=false,
    )
    set_device_model!(template_uc, storage_model)

    # network
    set_network_model!(
        template_uc,
        NetworkModel(network_model, use_slacks = true),
    )

    # services
    # TODO: support minimum number of synchronous generators online.
    # 
    # export ServiceModel
    # export RangeReserve
    # export RampReserve
    # export StepwiseCostReserve
    # export NonSpinningReserve
    # 
    # ServiceModel(PSY.AGC)
    # GroupReserve
    # 
    # minimum online units 
    # set_service_model!(
    #     template,
    #     ServiceModel(VariableReserve{ReserveUp}, RangeReserve, reserve_up_name),
    # )
    # set_service_model!(
    #     template,
    #     ServiceModel(VariableReserve{ReserveDown}, RangeReserve, reserve_down_name),
    # )
    # 
    # pfr (generator)
    # set_service_model!(
    #     template,
    #     ServiceModel(VariableReserve{ReserveUp}, RangeReserve)
    # )
    # set_service_model!(
    #     template,
    #     ServiceModel(VariableReserve{ReserveDown}, RangeReserve)
    # )
    # 
    # pfr (generator) + (storage)
    # set_service_model!(
    #     template,
    #     ServiceModel(VariableReserve{ReserveUp}, RangeReserve)
    # )
    # set_service_model!(
    #     template,
    #     ServiceModel(VariableReserve{ReserveDown}, RangeReserve)
    # )

    normalize_template_branch_keys!(template_uc)

    return template_uc
end
