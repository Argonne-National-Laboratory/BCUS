# Copyright © 2016 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.  Software changes,
#    modifications, or derivative works, should be noted with comments and the
#    author and organization's name.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor
#    the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# 4. The software and the end-user documentation included with the
#    redistribution, if any, must include the following acknowledgment:
#
#    "This product includes software produced by UChicago Argonne, LLC under
#     Contract No. DE-AC02-06CH11357 with the Department of Energy."
#
# *****************************************************************************
# DISCLAIMER
#
# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.
#
# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
#
# *****************************************************************************

# Modified Date and By:
# - Created on July 2015 by Yuna Zhang from Argonne National Laboratory
# - 01-apr-2017: Refactored to better match ruby coding standards by RTM
# 21-Apr-2017 RTM used rubocop linter for code cleanup
# 1. Introduction
# This is the subfunction called by Uncertain_Parameters to generate DX
# coil uncertainty distribution.
class DXCoilUncertainty
  attr_reader :dx_Coil_SingleSpeed_name
  attr_reader :dx_Coil_SingleSpeed_rated_COP
  attr_reader :dx_Coil_SingleSpeed_rated_Total_Cooling_Capacity
  attr_reader :dx_Coil_SingleSpeed_rated_Sensible_Heat_Ratio
  attr_reader :dx_Coil_SingleSpeed_rated_Air_Flow_Rate
  attr_reader :dx_Coil_TwoSpeed_name
  attr_reader :dx_Coil_TwoSpeed_rated_High_Speed_COP
  attr_reader :dx_Coil_TwoSpeed_rated_Low_Speed_COP

  def initialize
    @dx_Coil_SingleSpeed_name = []
    @dx_Coil_SingleSpeed_rated_COP = []
    @dx_Coil_SingleSpeed_rated_Total_Cooling_Capacity = []
    @dx_Coil_SingleSpeed_rated_Sensible_Heat_Ratio = []
    @dx_Coil_SingleSpeed_rated_Air_Flow_Rate = []
    @dx_Coil_TwoSpeed_name = []
    @dx_Coil_TwoSpeed_rated_High_Speed_COP = []
    @dx_Coil_TwoSpeed_rated_Low_Speed_COP = []
  end

  def dx_Coil_SingleSpeed_find(model)
    # loop through the air loop to find the dx coil
    air_loops = model.getAirLoopHVACs
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents
      supply_components.each do |supply_component|
        # find DX cooiling coil single speed in the airloop
        hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
        next if hvac_component.empty?
        hvac_component = hvac_component.get
        @dx_Coil_SingleSpeed_name << hvac_component.name.to_s
        if hvac_component.ratedCOP.to_f > 0
          @dx_Coil_SingleSpeed_rated_COP << hvac_component.ratedCOP.to_f
        end
        if hvac_component.ratedTotalCoolingCapacity.to_f > 0
          @dx_Coil_SingleSpeed_rated_Total_Cooling_Capacity << hvac_component.ratedTotalCoolingCapacity.to_f
        end
        if hvac_component.ratedSensibleHeatRatio.to_f > 0
          @dx_Coil_SingleSpeed_rated_Sensible_Heat_Ratio << hvac_component.ratedSensibleHeatRatio.to_f
        end
        if hvac_component.ratedAirFlowRate.to_f > 0
          @dx_Coil_SingleSpeed_rated_Air_Flow_Rate << hvac_component.ratedAirFlowRate.to_f
        end
      end
    end
  end

  def dx_Coil_TwoSpeed_find(model)
    # loop through the air loop to find the dx coil
    air_loops = model.getAirLoopHVACs
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents
      supply_components.each do |supply_component|
        # find DX cooiling coil Two speed in the air loop
        hvac_component = supply_component.to_CoilCoolingDXTwoSpeed
        next if hvac_component.empty?
        hvac_component = hvac_component.get
        @dx_Coil_TwoSpeed_name << hvac_component.name.to_s
        if hvac_component.ratedHighSpeedCOP.to_f > 0
          @dx_Coil_TwoSpeed_rated_High_Speed_COP << hvac_component.ratedHighSpeedCOP.to_f
        end
        if hvac_component.ratedLowSpeedCOP.to_f > 0
          @dx_Coil_TwoSpeed_rated_Low_Speed_COP << hvac_component.ratedLowSpeedCOP.to_f
        end
      end
    end
  end

  def dx_Coil_SingleSpeed_method(model, parameter_types, _parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /DXCoolingCoilSingleSpeedRatedTotalCapacity/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            next if supply_component.to_CoilCoolingDXSingleSpeed.empty?
            hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
            hvac_component = hvac_component.get
            hvac_component.setRatedTotalCoolingCapacity(parameter_value[index])
          end
        end
      elsif type =~ /DXCoolingCoilSingleSpeedRatedSenisbleHeatRatio/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            next if supply_component.to_CoilCoolingDXSingleSpeed.empty?
            hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
            hvac_component = hvac_component.get
            hvac_component.setRatedSensibleHeatRatio(parameter_value[index])
          end
        end
      elsif type =~ /DXCoolingCoilSingleSpeedRatedCOP/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            next if supply_component.to_CoilCoolingDXSingleSpeed.empty?
            hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
            hvac_component = hvac_component.get
            optional_double_cop = OpenStudio::OptionalDouble.new(parameter_value[index])
            hvac_component.setRatedCOP(optional_double_cop)
          end
        end
      elsif type =~ /DXCoolingCoilSingleSpeedRatedAirFlowRate/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            next if supply_component.to_CoilCoolingDXSingleSpeed.empty?
            hvac_component = supply_component.to_CoilCoolingDXSingleSpeed
            hvac_component = hvac_component.get
            hvac_component.setRatedAirFlowRate(parameter_value[index])
          end
        end
      end
    end
  end

  def dx_Coil_TwoSpeed_method(model, parameter_types, _parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /DXCoolingCoilTwoSpeedRatedHighSpeedCOP/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            next if supply_component.to_CoilCoolingDXTwoSpeed.empty?
            hvac_component = supply_component.to_CoilCoolingDXTwoSpeed
            hvac_component = hvac_component.get
            hvac_component.setRatedHighSpeedCOP(parameter_value[index])
          end
        end
      elsif type =~ /DXCoolingCoilTwoSpeedRatedLowSpeedCOP/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            next if supply_component.to_CoilCoolingDXTwoSpeed.empty?
            hvac_component = supply_component.to_CoilCoolingDXTwoSpeed
            hvac_component = hvac_component.get
            hvac_component.setRatedLowSpeedCOP(parameter_value[index])
          end
        end
      end
    end
  end
end
