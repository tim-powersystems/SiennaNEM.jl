using HydroPowerSimulations
using StorageSystemsSimulations
using PowerModels


function build_problem_base_uc(;network_model=NFAPowerModel)
    # NOTE:
    # The network_model can be from PowerModels or PowerSimulations. Examples:
    # 
    #   CopperPlatePowerModel,
    #   PTDFPowerModel,

    template_uc = ProblemTemplate()
    set_device_model!(template_uc, MonitoredLine, StaticBranchBounds)
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

    return template_uc
end
