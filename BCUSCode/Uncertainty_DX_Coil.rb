=begin of comments
Copyright © 201? , UChicago Argonne, LLC
All Rights Reserved
 [Software Name, Version 1.x??]
[Optional:  Authors name and organization}
OPEN SOURCE LICENSE

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.  Software changes, modifications, or derivative works, should be noted with comments and the author and organization’s name.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

4. The software and the end-user documentation included with the redistribution, if any, must include the following acknowledgment:

   "This product includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.”

******************************************************************************************************
DISCLAIMER

THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

***************************************************************************************************


Modified Date and By:
- Created on July 2015 by Yuna Zhang from Argonne National Laboratory
- 01-apr-2017: Refactored to better match ruby coding standards by RTM

1. Introduction
This is the subfunction called by Uncertain_Parameters to generate DX coil uncertainty distribution.

=end

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
    @dx_Coil_SingleSpeed_name = Array.new
    @dx_Coil_SingleSpeed_rated_COP = Array.new
    @dx_Coil_SingleSpeed_rated_Total_Cooling_Capacity = Array.new
    @dx_Coil_SingleSpeed_rated_Sensible_Heat_Ratio = Array.new
    @dx_Coil_SingleSpeed_rated_Air_Flow_Rate = Array.new
    @dx_Coil_TwoSpeed_name = Array.new
    @dx_Coil_TwoSpeed_rated_High_Speed_COP = Array.new
    @dx_Coil_TwoSpeed_rated_Low_Speed_COP = Array.new
  end

  def dx_Coil_SingleSpeed_find(model)
    # loop through the air loop to find the dx coil
    air_loops = model.getAirLoopHVACs
    air_loops.each do |air_loop|
      supply_components = air_loop.supplyComponents
      supply_components.each do |supply_component|
        #find DX cooiling coil single speed in the airloop
        hVACComponent = supply_component.to_CoilCoolingDXSingleSpeed
        unless hVACComponent.empty?
          hVACComponent = hVACComponent.get
          @dx_Coil_SingleSpeed_name << hVACComponent.name.to_s
          if hVACComponent.ratedCOP.to_f > 0
            @dx_Coil_SingleSpeed_rated_COP << hVACComponent.ratedCOP.to_f
          end
          if hVACComponent.ratedTotalCoolingCapacity.to_f > 0
            @dx_Coil_SingleSpeed_rated_Total_Cooling_Capacity << hVACComponent.ratedTotalCoolingCapacity.to_f
          end
          if hVACComponent.ratedSensibleHeatRatio.to_f > 0
            @dx_Coil_SingleSpeed_rated_Sensible_Heat_Ratio << hVACComponent.ratedSensibleHeatRatio.to_f
          end
          if hVACComponent.ratedAirFlowRate.to_f > 0
            @dx_Coil_SingleSpeed_rated_Air_Flow_Rate << hVACComponent.ratedAirFlowRate.to_f
          end
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
        #find DX cooiling coil Two speed in the air loop
        hVACComponent = supply_component.to_CoilCoolingDXTwoSpeed
        unless hVACComponent.empty?
          hVACComponent = hVACComponent.get
          @dx_Coil_TwoSpeed_name << hVACComponent.name.to_s
          if hVACComponent.ratedHighSpeedCOP.to_f > 0
            @dx_Coil_TwoSpeed_rated_High_Speed_COP << hVACComponent.ratedHighSpeedCOP.to_f
          end
          if hVACComponent.ratedLowSpeedCOP.to_f > 0
            @dx_Coil_TwoSpeed_rated_Low_Speed_COP << hVACComponent.ratedLowSpeedCOP.to_f
          end
        end
      end
    end
  end

  def dx_Coil_SingleSpeed_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /DXCoolingCoilSingleSpeedRatedTotalCapacity/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            unless supply_component.to_CoilCoolingDXSingleSpeed.empty?
              hVACComponent = supply_component.to_CoilCoolingDXSingleSpeed
              hVACComponent = hVACComponent.get
              hVACComponent.setRatedTotalCoolingCapacity(parameter_value[index])
            end
          end
        end
      elsif type =~ /DXCoolingCoilSingleSpeedRatedSenisbleHeatRatio/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            unless supply_component.to_CoilCoolingDXSingleSpeed.empty?
              hVACComponent = supply_component.to_CoilCoolingDXSingleSpeed
              hVACComponent = hVACComponent.get
              hVACComponent.setRatedSensibleHeatRatio(parameter_value[index])
            end
          end
        end
      elsif type =~ /DXCoolingCoilSingleSpeedRatedCOP/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            unless supply_component.to_CoilCoolingDXSingleSpeed.empty?
              hVACComponent = supply_component.to_CoilCoolingDXSingleSpeed
              hVACComponent = hVACComponent.get
              optionalDoubleCOP = OpenStudio::OptionalDouble.new(parameter_value[index])
              hVACComponent.setRatedCOP(optionalDoubleCOP)
            end
          end
        end
      elsif type =~ /DXCoolingCoilSingleSpeedRatedAirFlowRate/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            unless supply_component.to_CoilCoolingDXSingleSpeed.empty?
              hVACComponent = supply_component.to_CoilCoolingDXSingleSpeed
              hVACComponent = hVACComponent.get
              hVACComponent.setRatedAirFlowRate(parameter_value[index])
            end
          end
        end
      end
    end
  end

  def dx_Coil_TwoSpeed_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /DXCoolingCoilTwoSpeedRatedHighSpeedCOP/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            unless supply_component.to_CoilCoolingDXTwoSpeed.empty?
              hVACComponent = supply_component.to_CoilCoolingDXTwoSpeed
              hVACComponent = hVACComponent.get
              hVACComponent.setRatedHighSpeedCOP(parameter_value[index])
            end
          end
        end
      elsif type =~ /DXCoolingCoilTwoSpeedRatedLowSpeedCOP/
        model.getAirLoopHVACs.each do |air_loop|
          air_loop.supplyComponents.each do |supply_component|
            unless supply_component.to_CoilCoolingDXTwoSpeed.empty?
              hVACComponent = supply_component.to_CoilCoolingDXTwoSpeed
              hVACComponent = hVACComponent.get
              hVACComponent.setRatedLowSpeedCOP(parameter_value[index])
            end
          end
        end
      end
    end
  end
end 



 