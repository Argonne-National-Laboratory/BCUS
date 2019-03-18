=begin comments
Copyright © 2016 , UChicago Argonne, LLC
All Rights Reserved
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


1. Introduction
This is the subfunction called by Uncertain_Parameters to set uncertainty for operational parameters

=end

class OperationUncertainty < OpenStudio::Model::Model

  attr_reader :lights_space_type
  attr_reader :lights_watts_per_floor_area
  attr_reader :plugload_space_type
  attr_reader :plugload_watts_per_floor_area
  attr_reader :people_space_type
  attr_reader :people_floor_area_per_person

  def initialize
    @lights_space_type = Array.new
    @lights_watts_per_floor_area = Array.new
    @plugload_space_type = Array.new
    @plugload_watts_per_floor_area = Array.new
    @people_space_type = Array.new
    @people_floor_area_per_person = Array.new
  end

  def operation_parameters_find(model)
    space_types = model.getSpaceTypes # Space type is required entry to define a thermal space
    space_types.each do |space_type|
      if space_type.spaces.size > 0
        if space_type.lights.size > 0
          @lights_space_type << space_type.name
          if space_type.lights.size == 1
            space_type.lights.each do |light|
              if not light.powerPerFloorArea.empty?
                @lights_watts_per_floor_area << light.powerPerFloorArea.get
              else
                @lights_watts_per_floor_area << nil
              end
            end
          end
        end

        if space_type.electricEquipment.size > 0
          @plugload_space_type << space_type.name
          if space_type.electricEquipment.size == 1
            space_type.electricEquipment.each do |electricEquipment|
              if not electricEquipment.powerPerFloorArea.empty?
                @plugload_watts_per_floor_area << electricEquipment.powerPerFloorArea.get
              else
                @plugload_watts_per_floor_area << nil
              end
            end
          end
        end
        if space_type.people.size > 0
          @people_space_type << space_type.name
          if space_type.people.size == 1
            space_type.people.each do |people|
              unless people.spaceFloorAreaPerPerson.empty?
                @people_floor_area_per_person << 1 / people.peoplePerFloorArea.get
              else
                @people_floor_area_per_person << people.spaceFloorAreaPerPerson.get
              end
            end
          end
        end
      end
    end
  end

  def lights_watts_per_area_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /Lights_WattsPerSpaceFloorArea/
        space_types = model.getSpaceTypes # Space type is required entry to define a thermal space
        space_types.each do |space_type|
          if space_type.name.to_s =~/#{parameter_names[index]}/
            space_type.lights.each do |light|
              new_lights_def = OpenStudio::Model::LightsDefinition.new(model)
              new_lights_def.setWattsperSpaceFloorArea(parameter_value[index])
              light.setLightsDefinition(new_lights_def)
              # puts "debug-lights #{new_lights_def}"
            end
          end
        end
      end
    end
  end


  def plugload_watts_per_area_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /PlugLoad_WattsPerSpaceFloorArea/
        space_types = model.getSpaceTypes # Space type is required entry to define a thermal space
        space_types.each do |space_type|
          if space_type.name.to_s =~/#{parameter_names[index]}/
            space_type.electricEquipment.each do |equipment|
              new_equipment_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
              new_equipment_def.setWattsperSpaceFloorArea(parameter_value[index])
              equipment.setElectricEquipmentDefinition(new_equipment_def)
            end
          end
        end
      end
    end
  end


  def people_area_per_person_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if type =~ /People_SpaceFloorAreaPerPerson/
        space_types = model.getSpaceTypes # Space type is required entry to define a thermal space
        space_types.each do |space_type|
          if space_type.name.to_s =~/#{parameter_names[index]}/
            space_type.people.each do |people|
              new_people_def = OpenStudio::Model::PeopleDefinition.new(model)
              new_people_def.setSpaceFloorAreaperPerson(parameter_value[index])
              people.setPeopleDefinition(new_people_def)
            end
          end
        end
      end
    end
  end

end