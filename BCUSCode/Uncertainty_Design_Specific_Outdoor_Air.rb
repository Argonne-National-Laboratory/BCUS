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
# This is the subfunction called by uncertain_parameters to generate
# design specific outdoor air uncertainty distribution.

# Class to describe design specific outdoor air uncertainty
class DesignSpecificOutdoorAirUncertainty
  attr_reader :design_spec_OA_name
  attr_reader :design_spec_OA_flow_per_person
  attr_reader :design_spec_OA_flow_per_floor_area
  attr_reader :design_spec_OA_flow_rate

  def initialize
    # rubocop:disable Naming/VariableName
    @design_spec_OA_name = []
    @design_spec_OA_flow_per_person = []
    @design_spec_OA_flow_per_floor_area = []
    @design_spec_OA_flow_rate = []
    # rubocop:enable Naming/VariableName
  end

  # rubocop:disable Naming/MethodName
  def design_spec_OA_find(model)
    # Space type is required entry to define a thermal space
    space_types = model.getSpaceTypes
    instances_array = []
    space_types.each do |space_type|
      next if space_type.spaces.empty?
      instances_array << space_type.designSpecificationOutdoorAir
    end
    instances_array.each do |instance|
      next if instance.empty?
      instance = instance.get
      @design_spec_OA_name << instance.name.to_s
      if instance.outdoorAirFlowperPerson > 0
        @design_spec_OA_flow_per_person <<
          instance.outdoorAirFlowperPerson.to_f
      end
      if instance.outdoorAirFlowperFloorArea > 0
        @design_spec_OA_flow_per_floor_area <<
          instance.outdoorAirFlowperFloorArea.to_f
      end
      if instance.outdoorAirFlowRate > 0
        @design_spec_OA_flow_rate <<
          instance.outdoorAirFlowRate.to_f
      end
    end
  end

  def design_spec_OA_set(model, param_types, _param_names, param_values)
    param_types.each_with_index do |type, index|
      param_set =
        case type
        when /OutdoorAirFlowPerPerson/
          'setOutdoorAirFlowperPerson'
        when /OutdoorairFlowPerZoneFloorArea/
          'setOutdoorAirFlowperFloorArea'
        when /OutdoorAirFlowRate/
          'setOutdoorAirFlowRate'
        end
      next if param_set.nil?
      instances_array = []
      model.getSpaceTypes.each do |space_type|
        next if space_type.spaces.empty?
        instances_array << space_type.designSpecificationOutdoorAir
      end
      instances_array.each do |instance|
        next if instance.empty?
        instance = instance.get
        instance.send(param_set.to_sym, param_values[index])
      end
    end
  end
  # rubocop:enable Naming/MethodName
end
