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


class FanPumpUncertainty
  attr_reader :fan_ConstantVolume_name
  attr_reader :fan_ConstantVolume_efficiency
  attr_reader :fan_ConstantVolume_motorEfficiency
  attr_reader :fan_VariableVolume_name
  attr_reader :fan_VariableVolume_efficiency
  attr_reader :fan_VariableVolume_motorEfficiency
  attr_reader :pump_VariableSpeed_name
  attr_reader :pump_VariableSpeed_motorEfficiency
  attr_reader :pump_ConstantSpeed_name
  attr_reader :pump_ConstantSpeed_motorEfficiency


  def initialize
    @fan_ConstantVolume_name = Array.new
    @fan_ConstantVolume_efficiency = Array.new
    @fan_ConstantVolume_motorEfficiency = Array.new
    @fan_VariableVolume_name = Array.new
    @fan_VariableVolume_efficiency = Array.new
    @fan_VariableVolume_motorEfficiency = Array.new
    @pump_VariableSpeed_name = Array.new
    @pump_VariableSpeed_motorEfficiency = Array.new
    @pump_ConstantSpeed_name = Array.new
    @pump_ConstantSpeed_motorEfficiency = Array.new

  end

  def fan_find(model)
    # loop through to find the loop that fan is in and the corresponding name
    # of the fan
    loops = model.getLoops
    loops.each do |loop|
      supply_components = loop.supplyComponents
      # find fans on the loop
      supply_components.each do |supply_component|
        unless supply_component.to_FanConstantVolume.empty?
          hVACComponent = supply_component.to_FanConstantVolume.get
          @fan_ConstantVolume_name << hVACComponent.name.to_s
          @fan_ConstantVolume_efficiency << hVACComponent.fanEfficiency.to_f
          @fan_ConstantVolume_motorEfficiency <<
            hVACComponent.motorEfficiency.to_f
        end

        unless supply_component.to_FanVariableVolume.empty?
          hVACComponent = supply_component.to_FanVariableVolume.get
          @fan_VariableVolume_name << hVACComponent.name.to_s
          @fan_VariableVolume_efficiency << hVACComponent.fanEfficiency.to_f
          @fan_VariableVolume_motorEfficiency <<
            hVACComponent.motorEfficiency.to_f
        end
      end
    end
  end

  def pump_find(model)
    # loop through to find the loop that fan is in and the corresponding name
    # of the fan
    loops = model.getLoops
    loops.each do |loop|
      supply_components = loop.supplyComponents
      # find pumps on the loop
      supply_components.each do |supply_component|
        unless supply_component.to_PumpConstantSpeed.empty?
          hVACComponent = supply_component.to_PumpConstantSpeed.get
          @pump_ConstantSpeed_name << hVACComponent.name.to_s
          @pump_ConstantSpeed_motorEfficiency <<
            hVACComponent.motorEfficiency.to_f
        end

        unless supply_component.to_PumpVariableSpeed.empty?
          hVACComponent = supply_component.to_PumpVariableSpeed.get
          @pump_VariableSpeed_name << hVACComponent.name.to_s
          @pump_VariableSpeed_motorEfficiency <<
            hVACComponent.motorEfficiency.to_f
        end
      end
    end
  end

  def fan_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /FanConstantVolumeEfficiency/
        model.getLoops.each do |loop|
          loop.supplyComponents.each do |supply_component|
            unless supply_component.to_FanConstantVolume.empty?
              hVACComponent = supply_component.to_FanConstantVolume.get
              hVACComponent.setFanEfficiency(parameter_value[index])
            end
          end
        end
      elsif type =~ /FanConstantVolumeMotorEfficiency/
        model.getLoops.each do |loop|
          loop.supplyComponents.each do |supply_component|
            unless supply_component.to_FanConstantVolume.empty?
              hVACComponent = supply_component.to_FanConstantVolume.get
              hVACComponent.setMotorEfficiency(parameter_value[index])
            end
          end
        end
      elsif type =~ /FanVariableVolumeEfficiency/
        model.getLoops.each do |loop|
          loop.supplyComponents.each do |supply_component|
            unless supply_component.to_FanVariableVolume.empty?
              hVACComponent = supply_component.to_FanVariableVolume.get
              hVACComponent.setFanEfficiency(parameter_value[index])
            end
          end
        end
      elsif type =~ /FanVariableVolumeMotorEfficiency/
        model.getLoops.each do |loop|
          loop.supplyComponents.each do |supply_component|
            unless supply_component.to_FanVariableVolume.empty?
              hVACComponent = supply_component.to_FanVariableVolume.get
              hVACComponent.setMotorEfficiency(parameter_value[index])
            end
          end
        end
      end
    end
  end

  def pump_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /PumpConstantSpeedMotorEfficiency/
        model.getLoops.each do |loop|
          loop.supplyComponents.each do |supply_component|
            unless supply_component.to_PumpConstantSpeed.empty?
              hVACComponent = supply_component.to_PumpConstantSpeed.get
              hVACComponent.setMotorEfficiency(parameter_value[index])
            end
          end
        end
      elsif type =~ /PumpVariableSpeedMotorEfficiency/
        model.getLoops.each do |loop|
          loop.supplyComponents.each do |supply_component|
            unless supply_component.to_PumpVariableSpeed.empty?
              hVACComponent = supply_component.to_PumpVariableSpeed.get
              hVACComponent.setMotorEfficiency(parameter_value[index])
            end
          end
        end
      end
    end
  end

end
