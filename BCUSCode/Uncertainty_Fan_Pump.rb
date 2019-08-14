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
# This is the subfunction called by uncertain_parameters to generate fan
# and pump uncertainty distribution.
# This method applies the uncertainty analysis to all the fans and pumps
# in the loop. It cannot detect single fan on certain loop

# Class to describe fan pump uncertainty
class FanPumpUncertainty
  attr_reader :fan_constant_name
  attr_reader :fan_constant_efficiency
  attr_reader :fan_constant_motorEfficiency
  attr_reader :fan_variable_name
  attr_reader :fan_variable_efficiency
  attr_reader :fan_variable_motorEfficiency
  attr_reader :pump_constant_name
  attr_reader :pump_constant_motorEfficiency
  attr_reader :pump_variable_name
  attr_reader :pump_variable_motorEfficiency

  def initialize
    # rubocop:disable Naming/VariableName
    @fan_constant_name = []
    @fan_constant_efficiency = []
    @fan_constant_motorEfficiency = []
    @fan_variable_name = []
    @fan_variable_efficiency = []
    @fan_variable_motorEfficiency = []
    @pump_constant_name = []
    @pump_constant_motorEfficiency = []
    @pump_variable_name = []
    @pump_variable_motorEfficiency = []
    # rubocop:enable Naming/VariableName
  end

  def fan_find(model)
    # Loop through to find the loop that fan is in and the corresponding name
    # of the fan
    loops = model.getLoops
    loops.each do |loop|
      supply_components = loop.supplyComponents
      # Find fans on the loop
      supply_components.each do |supply_component|
        unless supply_component.to_FanConstantVolume.empty?
          component = supply_component.to_FanConstantVolume.get
          @fan_constant_name << component.name.to_s
          @fan_constant_efficiency << component.fanEfficiency.to_f
          @fan_constant_motorEfficiency << component.motorEfficiency.to_f
        end

        unless supply_component.to_FanVariableVolume.empty?
          component = supply_component.to_FanVariableVolume.get
          @fan_variable_name << component.name.to_s
          @fan_variable_efficiency << component.fanEfficiency.to_f
          @fan_variable_motorEfficiency << component.motorEfficiency.to_f
        end
      end
    end
  end

  def pump_find(model)
    # Loop through to find the loop that pump is in and the corresponding name
    # of the pump
    loops = model.getLoops
    loops.each do |loop|
      supply_components = loop.supplyComponents
      # find pumps on the loop
      supply_components.each do |supply_component|
        unless supply_component.to_PumpConstantSpeed.empty?
          component = supply_component.to_PumpConstantSpeed.get
          @pump_constant_name << component.name.to_s
          @pump_constant_motorEfficiency << component.motorEfficiency.to_f
        end

        unless supply_component.to_PumpVariableSpeed.empty?
          component = supply_component.to_PumpVariableSpeed.get
          @pump_variable_name << component.name.to_s
          @pump_variable_motorEfficiency << component.motorEfficiency.to_f
        end
      end
    end
  end

  def fan_set(model, param_types, param_names, param_values)
    supply_component_set(model, param_types, param_names, param_values)
  end

  def pump_set(model, param_types, param_names, param_values)
    supply_component_set(model, param_types, param_names, param_values)
  end

  def supply_component_set(model, param_types, _param_names, param_values)
    param_types.each_with_index do |type, index|
      param_get, param_set =
        case type
        when /FanConstantVolumeEfficiency/
          %w[to_FanConstantVolume setFanEfficiency]
        when /FanConstantVolumeMotorEfficiency/
          %w[to_FanConstantVolume setMotorEfficiency]
        when /FanVariableVolumeEfficiency/
          %w[to_FanVariableVolume setFanEfficiency]
        when /FanVariableVolumeMotorEfficiency/
          %w[to_FanVariableVolume setMotorEfficiency]
        when /PumpConstantSpeedMotorEfficiency/
          %w[to_PumpConstantSpeed setMotorEfficiency]
        when /PumpVariableSpeedMotorEfficiency/
          %w[to_PumpVariableSpeed setMotorEfficiency]
        else
          [nil, nil]
        end
      next if param_get.nil?
      model.getLoops.each do |loop|
        loop.supplyComponents.each do |supply_component|
          unless supply_component.send(param_get.to_sym).empty?
            component = supply_component.send(param_get.to_sym).get
            component.send(param_set.to_sym, param_values[index])
          end
        end
      end
    end
  end
end
