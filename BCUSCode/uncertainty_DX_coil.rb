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

# ******************************************************************************
# DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

# ******************************************************************************

# Modified Date and By:
# - Created on July 2015 by Yuna Zhang from Argonne National Laboratory

# 1. Introduction
# This is the subfunction called by uncertain_parameters to generate DX coil
# uncertainty distribution.

# Class to describe DX coil uncertainty
class DXCoilUncertainty
  attr_reader :DX_coil_single_speed_name
  attr_reader :DX_coil_single_speed_COP
  attr_reader :DX_coil_single_speed_totalCapacity
  attr_reader :DX_coil_single_speed_sensibleHeatRatio
  attr_reader :DX_coil_single_speed_airFlowRate
  attr_reader :DX_coil_two_speed_name
  attr_reader :DX_coil_two_speed_highCOP
  attr_reader :DX_coil_two_speed_lowCOP

  def initialize
    # rubocop:disable Naming/VariableName
    @DX_coil_single_speed_name = []
    @DX_coil_single_speed_COP = []
    @DX_coil_single_speed_totalCapacity = []
    @DX_coil_single_speed_sensibleHeatRatio = []
    @DX_coil_single_speed_airFlowRate = []
    @DX_coil_two_speed_name = []
    @DX_coil_two_speed_highCOP = []
    @DX_coil_two_speed_lowCOP = []
    # rubocop:enable Naming/VariableName
  end

  # rubocop:disable Naming/MethodName
  def DX_coil_single_speed_find(model)
    # Loop through the air loop to find the DX coil
    air_loops = model.getAirLoopHVACs
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents
      supply_components.each do |supply_component|
        # Find DX cooiling coil single speed in the airloop
        component = supply_component.to_CoilCoolingDXSingleSpeed
        next if component.empty?
        component = component.get
        @DX_coil_single_speed_name << component.name.to_s
        if component.ratedCOP.to_f > 0
          @DX_coil_single_speed_COP << component.ratedCOP.to_f
        end
        if component.ratedTotalCoolingCapacity.to_f > 0
          @DX_coil_single_speed_totalCapacity <<
            component.ratedTotalCoolingCapacity.to_f
        end
        if component.ratedSensibleHeatRatio.to_f > 0
          @DX_coil_single_speed_sensibleHeatRatio <<
            component.ratedSensibleHeatRatio.to_f
        end
        if component.ratedAirFlowRate.to_f > 0
          @DX_coil_single_speed_airFlowRate <<
            component.ratedAirFlowRate.to_f
        end
      end
    end
  end

  def DX_coil_two_speed_find(model)
    # Loop through the air loop to find the DX coil
    air_loops = model.getAirLoopHVACs
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents
      supply_components.each do |supply_component|
        # Find DX cooiling coil two speed in the air loop
        component = supply_component.to_CoilCoolingDXTwoSpeed
        next if component.empty?
        component = component.get
        @DX_coil_two_speed_name << component.name.to_s
        if component.ratedHighSpeedCOP.to_f > 0
          @DX_coil_two_speed_highCOP << component.ratedHighSpeedCOP.to_f
        end
        if component.ratedLowSpeedCOP.to_f > 0
          @DX_coil_two_speed_lowCOP << component.ratedLowSpeedCOP.to_f
        end
      end
    end
  end

  def DX_coil_single_speed_set(model, param_types, param_names, param_values)
    self.DX_coil_set(model, param_types, param_names, param_values)
  end

  def DX_coil_two_speed_set(model, param_types, param_names, param_values)
    self.DX_coil_set(model, param_types, param_names, param_values)
  end

  def DX_coil_set(model, param_types, _param_names, param_values)
    param_types.each_with_index do |type, index|
      param_get, param_set =
        case type
        when /DXCoolingCoilSingleSpeedRatedTotalCapacity/
          %w[to_CoilCoolingDXSingleSpeed setRatedTotalCoolingCapacity]
        when /DXCoolingCoilSingleSpeedRatedSenisbleHeatRatio/
          %w[to_CoilCoolingDXSingleSpeed setRatedSensibleHeatRatio]
        when /DXCoolingCoilSingleSpeedRatedCOP/
          %w[to_CoilCoolingDXSingleSpeed setRatedCOP]
        when /DXCoolingCoilSingleSpeedRatedAirFlowRate/
          %w[to_CoilCoolingDXSingleSpeed setRatedAirFlowRate]
        when /DXCoolingCoilTwoSpeedRatedHighSpeedCOP/
          %w[to_CoilCoolingDXTwoSpeed setRatedHighSpeedCOP]
        when /DXCoolingCoilTwoSpeedRatedLowSpeedCOP/
          %w[to_CoilCoolingDXTwoSpeed setRatedLowSpeedCOP]
        else
          [nil, nil]
        end
      next if param_get.nil?
      model.getAirLoopHVACs.each do |air_loop|
        air_loop.supplyComponents.each do |supply_component|
          unless supply_component.send(param_get.to_sym).empty?
            component = supply_component.send(param_get.to_sym).get
            component.send(param_set.to_sym, param_values[index])
          end
        end
      end
    end
  end
  # rubocop:enable Naming/MethodName
end
