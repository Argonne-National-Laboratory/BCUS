# Copyright © 2019, UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.  Software changes,
#    modifications, or derivative works, should be noted with comments and the
#    author and organization's name.

# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.

# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor
#    the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.

# 4. The software and the end-user documentation included with the
#    redistribution, if any, must include the following acknowledgment:

#    "This product includes software produced by UChicago Argonne, LLC under
#     Contract No. DE-AC02-06CH11357 with the Department of Energy."

# *****************************************************************************
# DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

# *****************************************************************************

# Modified Date and By:
# - Update 27-Mar-2017 by RTM
# to add verbose printouts and finished the error messages
# using abort() when UQ parameters are not found
# - Update 27-Mar-2017 by RTM
# renaming the uncertain parameter libraries so the first
# word is Uncertainty to help directory sorting
# 21-Apr-2017 by RTM
# ran rubocop lint for code cleanup

# - Updated on July 2016 by Yuna Zhang from Argonne National Laboratory
# - Created on Feb 27, 2015 by Yuming Sun and Matt Riddle from Argonne

# 1. Introduction
# This is the main code used for searching model for parameters to be
# perturbued for uncertainty and sensitivity analysis.

# 2. Call structure
# Refer to 'Function Call Structure_UA.pptx'

#===============================================================%
#     author: Yuming Sun and Matt Riddle                        %
#     date: Feb 27, 2015                                        %
#===============================================================%

# Main code used for searching model for parameters to be perturbued for
# uncertainty and sensitivity analysis

# uncertain_parameters
require_relative 'uncertainty_boiler'
require_relative 'uncertainty_chiller'
require_relative 'uncertainty_design_specific_outdoor_air'
require_relative 'uncertainty_DX_coil'
require_relative 'uncertainty_envelop'
require_relative 'uncertainty_fan_pump'
require_relative 'uncertainty_operation'
require_relative 'uncertainty_thermostat'
require 'csv'
require 'rubyXL'

class UncertainParameters
  def initialize
    @envelop_uncertainty = EnvelopUncertainty.new
    @operation_uncertainty = OperationUncertainty.new
    @boiler_uncertainty = BoilerUncertainty.new
    @fan_pump_uncertainty = FanPumpUncertainty.new
    @design_spec_OA_uncertainty = DesignSpecificOutdoorAirUncertainty.new
    @DX_cooling_coil_uncertainty = DXCoilUncertainty.new
    @chillerEIR_uncertainty = ChillerUncertainty.new
    @thermostat_uncertainty = ThermostatUncertainty.new
  end

  # Write into the uq cvs the uncertainty distribution information
  def find(model, uq_table, out_file_path_name, verbose = false)
    @envelop_uncertainty.material_find(model)
    @operation_uncertainty.operation_parameters_find(model)
    @boiler_uncertainty.boiler_find(model)
    @fan_pump_uncertainty.fan_find(model)
    @fan_pump_uncertainty.pump_find(model)
    @design_spec_OA_uncertainty.design_spec_outdoor_air_find(model)
    @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_find(model)
    @DX_cooling_coil_uncertainty.dx_Coil_TwoSpeed_find(model)
    @chillerEIR_uncertainty.chiller_find(model)
    # Create a csv file that contains uncertain parameters
    CSV.open(out_file_path_name.to_s, 'wb') do |csv| # Create file for writting
      csv << [
        'Parameter Type', 'Object in the model', 'Parameter Base Value',
        'Distribution', 'Mean or Mode', 'Std Dev', 'Min', 'Max'
      ]
    end

    # rubocop:disable LineLength
    # Write in the created csv file (take input from uncertainty)
    CSV.open(out_file_path_name.to_s, 'a+') do |csv|
      uq_table.each do |uq_param|
        next if uq_param[3] == 'Off'
        puts "Searching for #{uq_param[1]} #{uq_param[2]} in the model" if verbose
        case uq_param[1]
        when /StandardOpaqueMaterial/
          case uq_param[2]
          when /Conductivity/
            @envelop_uncertainty.std_material_conductivity.each_with_index do |conductivity, index|
              csv << [
                'Conductivity',
                @envelop_uncertainty.std_material_name[index],
                conductivity,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /Density/
            @envelop_uncertainty.std_material_density.each_with_index do |density, index|
              csv << [
                'Density',
                @envelop_uncertainty.std_material_name[index],
                density,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /SpecificHeat/
            @envelop_uncertainty.std_material_specificHeat.each_with_index do |specificHeat, index|
              csv << [
                'Specific Heat',
                @envelop_uncertainty.std_material_name[index],
                specificHeat,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /SolarAbsorptance/
            @envelop_uncertainty.std_material_solarAbsorptance.each_with_index do |solarAbsorptance, index|
              csv << [
                'Solar Absorptance',
                @envelop_uncertainty.std_material_name[index],
                solarAbsorptance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /ThermalAbsorptance/
            @envelop_uncertainty.std_material_thermalAbsorptance.each_with_index do |thermalAbsorptance, index|
              csv << [
                'Thermal Absorptance',
                @envelop_uncertainty.std_material_name[index],
                thermalAbsorptance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /VisibleAbsorptance/
            @envelop_uncertainty.std_material_visibleAbsorptance.each_with_index do |visibleAbsorptance, index|
              csv << [
                'Visible Absorptance',
                @envelop_uncertainty.std_material_name[index],
                visibleAbsorptance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! StandardOpaqueMaterial #{uq_param[2]} not found\n\n")
          end
        when /StandardGlazing/
          case uq_param[2]
          when /Conductivity/
            @envelop_uncertainty.std_glazing_conductivity.each_with_index do |conductivity, index|
              csv << [
                'Conductivity',
                @envelop_uncertainty.std_glazing_material_name[index],
                conductivity,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /ThermalResistance/
            @envelop_uncertainty.std_glazing_thermalResistance.each_with_index do |thermalResistance, index|
              csv << [
                'ThermalResistance',
                @envelop_uncertainty.std_glazing_material_name[index],
                thermalResistance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /SolarTransmittance/
            @envelop_uncertainty.std_glazing_solarTransmittance.each_with_index do |solarTransmittance, index|
              csv << [
                'SolarTransmittance',
                @envelop_uncertainty.std_glazing_material_name[index],
                solarTransmittance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /FrontSideSolarReflectance/
            @envelop_uncertainty.std_glazing_frontSideSolarReflectanceatNormalIncidence.each_with_index do |frontSideSolarReflectanceatNormalIncidence, index|
              csv << [
                'FrontSideSolarReflectance',
                @envelop_uncertainty.std_glazing_material_name[index],
                frontSideSolarReflectanceatNormalIncidence,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /BackSideSolarReflectance/
            @envelop_uncertainty.std_glazing_backSideSolarReflectanceatNormalIncidence.each_with_index do |backSideSolarReflectanceatNormalIncidence, index|
              csv << [
                'BackSideSolarReflectance',
                @envelop_uncertainty.std_glazing_material_name[index],
                backSideSolarReflectanceatNormalIncidence,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /InfraredTransmittance/
            @envelop_uncertainty.std_glazing_infraredTransmittance.each_with_index do |infraredTransmittance, index|
              csv << [
                'InfraredTransmittance',
                @envelop_uncertainty.std_glazing_material_name[index],
                infraredTransmittance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /VisibleTransmittance/
            @envelop_uncertainty.std_glazing_visibleTransmittanceatNormalIncidence.each_with_index do |visibleTransmittanceatNormalIncidence, index|
              csv << [
                'VisibleTransmittance',
                @envelop_uncertainty.std_glazing_material_name[index],
                visibleTransmittanceatNormalIncidence,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /FrontSideVisibleReflectance/
            @envelop_uncertainty.std_glazing_frontSideVisibleReflectanceatNormalIncidence.each_with_index do |frontSideVisibleReflectanceatNormalIncidence, index|
              csv << [
                'FrontSideVisibleReflectance',
                @envelop_uncertainty.std_glazing_material_name[index],
                frontSideVisibleReflectanceatNormalIncidence,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /BackSideVisibleReflectance/
            @envelop_uncertainty.std_glazing_backSideVisibleReflectanceatNormalIncidence.each_with_index do |backSideVisibleReflectanceatNormalIncidence, index|
              csv << [
                'BackSideVisibleReflectance',
                @envelop_uncertainty.std_glazing_material_name[index],
                backSideVisibleReflectanceatNormalIncidence,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /FrontSideInfraredHemisphericalEmissivity/
            @envelop_uncertainty.std_glazing_frontSideInfraredHemisphericalEmissivity.each_with_index do |frontSideInfraredHemisphericalEmissivity, index|
              csv << [
                'FrontSideInfraredHemisphericalEmissivity',
                @envelop_uncertainty.std_glazing_material_name[index],
                frontSideInfraredHemisphericalEmissivity,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /BackSideInfraredHemisphericalEmissivity/
            @envelop_uncertainty.std_glazing_backSideInfraredHemisphericalEmissivity.each_with_index do |backSideInfraredHemisphericalEmissivity, index|
              csv << [
                'BackSideInfraredHemisphericalEmissivity',
                @envelop_uncertainty.std_glazing_material_name[index],
                backSideInfraredHemisphericalEmissivity,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /DirtCorrectionFactor/
            @envelop_uncertainty.std_glazing_dirtCorrectionFactorforSolarandVisibleTransmittance.each_with_index do |dirtCorrectionFactorforSolarandVisibleTransmittance, index|
              csv << [
                'DirtCorrectionFactor',
                @envelop_uncertainty.std_glazing_material_name[index],
                dirtCorrectionFactorforSolarandVisibleTransmittance,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! StandardGlazing #{uq_param[2]} not found\n\n")
          end
        when /Infiltration/
          case uq_param[2]
          when /FlowPerExteriorArea/
            csv << [
              'Infiltration',
              'FlowPerExteriorArea',
              '',
              uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
            ]
          else
            abort("\n!!!ABORTING!!! Infiltration #{uq_param[2]} not found\n\n")
          end

        when /Lights/
          case uq_param[2]
          when /WattsPerSpaceFloorArea/
            @operation_uncertainty.lights_space_type.each_with_index do |spacetype, index|
              csv << [
                'Lights_WattsPerSpaceFloorArea',
                spacetype,
                @operation_uncertainty.lights_watts_per_floor_area[index],
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! Lights #{uq_param[2]} not found\n\n")
          end
        when /PlugLoad/
          case uq_param[2]
          when /WattsPerSpaceFloorArea/
            @operation_uncertainty.plugload_space_type.each_with_index do |spacetype, index|
              csv << [
                'PlugLoad_WattsPerSpaceFloorArea',
                spacetype,
                @operation_uncertainty.plugload_watts_per_floor_area[index],
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! PlugLoad #{uq_param[2]} not found\n\n")
          end
        when /People/
          case uq_param[2]
          when /SpaceFloorAreaPerPerson/
            @operation_uncertainty.people_space_type.each_with_index do |spacetype, index|
              csv << [
                'People_SpaceFloorAreaPerPerson',
                spacetype,
                @operation_uncertainty.people_floor_area_per_person[index],
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! People #{uq_param[2]} not found\n\n")
          end
        when /HotWaterBoiler/
          case uq_param[2]
          when /Efficiency/
            @boiler_uncertainty.hotwaterboiler_thermal_efficiency.each_with_index do |efficiency, index|
              csv << [
                'HotWaterBoilerEfficiency',
                @boiler_uncertainty.hotwaterboiler_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! HotWaterBoiler #{uq_param[2]} not found\n\n")
          end
        when /SteamBoiler/
          case uq_param[2]
          when /Efficiency/
            @boiler_uncertainty.steamboiler_thermal_efficiency.each_with_index do |efficiency, index|
              csv << [
                'SteamBoilerEfficiency',
                @boiler_uncertainty.steamboiler_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! SteamBoiler #{uq_param[2]} not found\n\n")
          end
        when /FanConstantVolume/
          case uq_param[2]
          when /Efficiency/
            @fan_pump_uncertainty.fan_ConstantVolume_efficiency.each_with_index do |efficiency, index|
              csv << [
                'FanConstantVolumeEfficiency',
                @fan_pump_uncertainty.fan_ConstantVolume_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /Motor_efficiency/
            @fan_pump_uncertainty.fan_ConstantVolume_motorEfficiency.each_with_index do |efficiency, index|
              csv << [
                'FanConstantVolumeMotorEfficiency',
                @fan_pump_uncertainty.fan_ConstantVolume_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! FanConstantVolume #{uq_param[2]} not found\n\n")
          end
        when /FanVariableVolume/
          case uq_param[2]
          when /Efficiency/
            @fan_pump_uncertainty.fan_VariableVolume_efficiency.each_with_index do |efficiency, index|
              csv << [
                'FanVariableVolumeEfficiency',
                @fan_pump_uncertainty.fan_VariableVolume_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /Motor_efficiency/
            @fan_pump_uncertainty.fan_VariableVolume_motorEfficiency.each_with_index do |efficiency, index|
              csv << [
                'FanVariableVolumeMotorEfficiency',
                @fan_pump_uncertainty.fan_VariableVolume_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! FanVariableVolume #{uq_param[2]} not found\n\n")
          end
        when /PumpConstantSpeed/
          case uq_param[2]
          when /Motor_efficiency/
            @fan_pump_uncertainty.pump_ConstantSpeed_motorEfficiency.each_with_index do |efficiency, index|
              csv << [
                'PumpConstantSpeedMotorEfficiency',
                @fan_pump_uncertainty.pump_ConstantSpeed_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! PumpConstantSpeed #{uq_param[2]} not found\n\n")
          end
        when /PumpVariableSpeed/
          case uq_param[2]
          when /Motor_efficiency/
            @fan_pump_uncertainty.pump_VariableSpeed_motorEfficiency.each_with_index do |efficiency, index|
              csv << [
                'PumpVariableSpeedMotorEfficiency',
                @fan_pump_uncertainty.pump_VariableSpeed_name[index],
                efficiency,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! PumpVariablespeed #{uq_param[2]} not found\n\n")
          end
        when /DesignSpecificationOutdoorAir/
          case uq_param[2]
          when /OutdoorAirFlowPerPerson/
            @design_spec_OA_uncertainty.design_spec_outdoor_air_flow_per_person.each_with_index do |airflow, index|
              csv << [
                'DesignSpecificOutdoorAirFlowPerPerson',
                @design_spec_OA_uncertainty.design_spec_outdoor_air_name[index],
                airflow,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /OutdoorairFlowPerZoneFloorArea/
            @design_spec_OA_uncertainty.design_spec_outdoor_air_flow_per_floor_area.each_with_index do |airflow, index|
              csv << [
                'DesignSpecificOutdoorAirFlowPerZoneFloorArea',
                @design_spec_OA_uncertainty.design_spec_outdoor_air_name[index],
                airflow,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /OutdoorAirFlowRate/
            @design_spec_OA_uncertainty.design_spec_outdoor_air_flow_rate.each_with_index do |airflow, index|
              csv << [
                'DesignSpecificOutdoorAirFlowRate',
                @design_spec_OA_uncertainty.design_spec_outdoor_air_name[index],
                airflow,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! DesignSpecificationOutdoorAir #{uq_param[2]} not found\n\n")
          end
        when /SingleSpeedDXCoolingUnits/
          case uq_param[2]
          when /RatedTotalCoolingCapacity/
            @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_rated_Total_Cooling_Capacity.each_with_index do |capacity, index|
              csv << [
                'DXCoolingCoilSingleSpeedRatedTotalCapacity',
                @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_name[index],
                capacity,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /RatedSenisbleHeatRatio/
            @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_rated_Sensible_Heat_Ratio.each_with_index do |heatratio, index|
              csv << [
                'DXCoolingCoilSingleSpeedRatedSenisbleHeatRatio',
                @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_name[index],
                heatratio,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /RatedCOP/
            @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_rated_COP.each_with_index do |cop, index|
              csv << [
                'DXCoolingCoilSingleSpeedRatedCOP',
                @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_name[index],
                cop,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /RatedAirFlowRate/
            @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_rated_Air_Flow_Rate.each_with_index do |airflow, index|
              csv << [
                'DXCoolingCoilSingleSpeedRatedAirFlowRate',
                @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_name[index],
                airflow,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! SingleSpeedDXCoolingUnits #{uq_param[2]} not found\n\n")
          end
        when /TwoSpeedDXCoolingUnits/
          case uq_param[2]
          when /RatedHighSpeedCOP/
            @DX_cooling_coil_uncertainty.dx_Coil_TwoSpeed_rated_High_Speed_COP.each_with_index do |cop, index|
              csv << [
                'DXCoolingCoilTwoSpeedRatedHighSpeedCOP',
                @DX_cooling_coil_uncertainty.dx_Coil_TwoSpeed_name[index],
                cop,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          when /RatedLowSpeedCOP/
            @DX_cooling_coil_uncertainty.dx_Coil_TwoSpeed_rated_Low_Speed_COP.each_with_index do |cop, index|
              csv << [
                'DXCoolingCoilTwoSpeedRatedLowSpeedCOP',
                @DX_cooling_coil_uncertainty.dx_Coil_TwoSpeed_name[index],
                cop,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! TwoSpeedDXCoolingUnits #{uq_param[2]} not found\n\n")
          end
        when /ChillerElectricEIR/
          case uq_param[2]
          when /ReferenceCOP/
            @chillerEIR_uncertainty.chiller_Reference_COP.each_with_index do |cop, index|
              csv << [
                'ChillerElectricEIRReferenceCOP',
                @chillerEIR_uncertainty.chiller_name[index],
                cop,
                uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
              ]
            end
          else
            abort("\n!!!ABORTING!!! ChillerElectricEIR #{uq_param[2]} not found\n\n")
          end
        when /ThermostatSettings/
          case uq_param[2]
          when /ThermostatSetpointCooling/
            csv << [
              'CoolingSetpoint',
              'DualSetpoint:CoolingSetpoint',
              'CoolingSetpointTemperature',
              uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
            ]
          when /ThermostatSetpointHeating/
            csv << [
              'HeatingSetpoint',
              'DualSetpoint:HeatingSetpoint',
              'HeatingSetpointTemperature',
              uq_param[4], uq_param[5], uq_param[6], uq_param[7], uq_param[8]
            ]
          else
            abort("\n!!!ABORTING!!! #{uq_param[2]} not found\n\n")
          end
        else
          abort("\n!!!ABORTING!!! UQ Class #{uq_param[1]} not found\n\n")
        end
      end
    end
    puts "#{out_file_path_name} has been generated." if verbose
  end

  def apply(model, parameter_types, parameter_names, parameter_value)
    @envelop_uncertainty.material_set(model, parameter_types, parameter_names, parameter_value)
    @envelop_uncertainty.infiltration_flow_per_ext_surface_method(model, parameter_types, parameter_names, parameter_value)
    @operation_uncertainty.lights_watts_per_area_method(model, parameter_types, parameter_names, parameter_value)
    @operation_uncertainty.plugload_watts_per_area_method(model, parameter_types, parameter_names, parameter_value)
    @operation_uncertainty.people_area_per_person_method(model, parameter_types, parameter_names, parameter_value)
    @boiler_uncertainty.boiler_efficiency_method(model, parameter_types, parameter_names, parameter_value)
    @fan_pump_uncertainty.fan_method(model, parameter_types, parameter_names, parameter_value)
    @fan_pump_uncertainty.pump_method(model, parameter_types, parameter_names, parameter_value)
    @design_spec_OA_uncertainty.design_spec_outdoor_air_method(model, parameter_types, parameter_names, parameter_value)
    @DX_cooling_coil_uncertainty.dx_Coil_SingleSpeed_method(model, parameter_types, parameter_names, parameter_value)
    @DX_cooling_coil_uncertainty.dx_Coil_TwoSpeed_method(model, parameter_types, parameter_names, parameter_value)
    @chillerEIR_uncertainty.chiller_method(model, parameter_types, parameter_names, parameter_value)
  end

  def thermostat_adjust(
    model, uq_table, out_file_path_name, model_output_path,
    parameter_types, parameter_value
  )
    # Create a csv file that contains thermostat if the user turn it on

    CSV.open(out_file_path_name.to_s, 'wb') do |csv| # Create file for writting
      csv << [
        'Parameter Type', 'Object in the model',
        'Parameter Base Value', 'Adjusted Value'
      ]
    end

    CSV.open(out_file_path_name.to_s, 'a+') do |csv|
      uq_table.each do |uq_param|
        next if uq_param[3] == 'Off'
        case uq_param[1]
        when /ThermostatSettings/
          case uq_param[2]
          when /ThermostatSetpointCooling/
            parameter_types.each_with_index do |type, index|
              next unless type =~ /CoolingSetpoint/
              adjust_value_cooling = parameter_value[index]
              @thermostat_uncertainty.cooling_method(
                model, adjust_value_cooling, model_output_path
              )
              @thermostat_uncertainty.clg_sch_set_values.each_with_index do |value, index1|
                csv << [
                  'CoolingSetpoint',
                  @thermostat_uncertainty.clg_set_schs_name[index1],
                  value,
                  parameter_value[index]
                ]
              end
            end
          when /ThermostatSetpointHeating/
            parameter_types.each_with_index do |type, index|
              next unless type =~ /HeatingSetpoint/
              adjust_value_heating = parameter_value[index]
              @thermostat_uncertainty.heating_method(
                model, adjust_value_heating, model_output_path
              )
              @thermostat_uncertainty.htg_sch_set_values.each_with_index do |value, index1|
                csv << [
                  'HeatingSetpoint',
                  @thermostat_uncertainty.htg_set_schs_name[index1],
                  value,
                  parameter_value[index]
                ]
              end
            end
          end
        end
      end
    end
  end
end
# rubocop:enable LineLength
