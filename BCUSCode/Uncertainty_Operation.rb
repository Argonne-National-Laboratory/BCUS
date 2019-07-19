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
# This is the subfunction called by uncertain_parameters to set uncertainty
# for operational parameters

# Class for operational uncertainty
class OperationUncertainty < OpenStudio::Model::Model
  attr_reader :lights_space_type
  attr_reader :lights_watts_per_floor_area
  attr_reader :plugload_space_type
  attr_reader :plugload_watts_per_floor_area
  attr_reader :people_space_type
  attr_reader :people_floor_area_per_person

  def initialize
    @lights_space_type = []
    @lights_watts_per_floor_area = []
    @plugload_space_type = []
    @plugload_watts_per_floor_area = []
    @people_space_type = []
    @people_floor_area_per_person = []
  end

  def operation_parameters_find(model)
    # Space type is required entry to define a thermal space
    space_types = model.getSpaceTypes

    space_types.each do |space_type|
      next if space_type.spaces.empty?
      unless space_type.lights.empty?
        if space_type.lights.size == 1
          space_type.lights.each do |light|
            next if light.powerPerFloorArea.empty?
            @lights_space_type << space_type.name
            @lights_watts_per_floor_area << light.powerPerFloorArea.get
          end
        end
      end

      unless space_type.electricEquipment.empty?
        if space_type.electricEquipment.size == 1
          space_type.electricEquipment.each do |electric_equipment|
            next if electric_equipment.powerPerFloorArea.empty?
            @plugload_space_type << space_type.name
            @plugload_watts_per_floor_area <<
              electric_equipment.powerPerFloorArea.get
          end
        end
      end

      unless space_type.people.empty?
        if space_type.people.size == 1
          space_type.people.each do |people|
            if !people.spaceFloorAreaPerPerson.empty?
              @people_space_type << space_type.name
              @people_floor_area_per_person <<
                people.spaceFloorAreaPerPerson.get
            elsif !people.peoplePerFloorArea.empty?
              @people_space_type << space_type.name
              @people_floor_area_per_person <<
                1 / people.peoplePerFloorArea.get
            else
              next
            end
          end
        end
      end
    end
  end

  def lights_watts_per_area_set(
    model, parameter_types, parameter_names, parameter_value
  )
    parameter_types.each_with_index do |type, index|
      next unless type =~ /Lights_WattsPerSpaceFloorArea/
      # Space type is required entry to define a thermal space
      space_types = model.getSpaceTypes
      space_types.each do |space_type|
        next unless space_type.name.to_s =~ /#{parameter_names[index]}/
        space_type.lights.each do |light|
          new_lights_def = OpenStudio::Model::LightsDefinition.new(model)
          new_lights_def.setWattsperSpaceFloorArea(parameter_value[index])
          light.setLightsDefinition(new_lights_def)
        end
      end
    end
  end

  def plugload_watts_per_area_set(
    model, parameter_types, parameter_names, parameter_value
  )
    parameter_types.each_with_index do |type, index|
      next unless type =~ /PlugLoad_WattsPerSpaceFloorArea/
      # Space type is required entry to define a thermal space
      space_types = model.getSpaceTypes
      space_types.each do |space_type|
        next unless space_type.name.to_s =~ /#{parameter_names[index]}/
        space_type.electricEquipment.each do |equipment|
          new_equipment_def =
            OpenStudio::Model::ElectricEquipmentDefinition.new(model)
          new_equipment_def.setWattsperSpaceFloorArea(parameter_value[index])
          equipment.setElectricEquipmentDefinition(new_equipment_def)
        end
      end
    end
  end

  def people_area_per_person_set(
    model, parameter_types, parameter_names, parameter_value
  )
    parameter_types.each_with_index do |type, index|
      next unless type =~ /People_SpaceFloorAreaPerPerson/
      # Space type is required entry to define a thermal space
      space_types = model.getSpaceTypes
      space_types.each do |space_type|
        next unless space_type.name.to_s =~ /#{parameter_names[index]}/
        space_type.people.each do |people|
          new_people_def = OpenStudio::Model::PeopleDefinition.new(model)
          new_people_def.setSpaceFloorAreaperPerson(parameter_value[index])
          people.setPeopleDefinition(new_people_def)
        end
      end
    end
  end
end
