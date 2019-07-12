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
- Updated on Junly 2016 by Yuna Zhang from Argonne National Laboratory
- Updated on June 2015 by Yuna Zhang from Argonne National Laboratory
- Created on March 2015 by Yuming Sun from Argonne National Laboratory

1. Introduction
This is the subfunction called by uncertain_parameters to generate envelop uncertainty distribution.

=end

class EnvelopUncertainty < OpenStudio::Model::Model

  attr_reader :std_material_name
  attr_reader :std_material_conductivity
  attr_reader :std_material_density
  attr_reader :std_material_specificHeat
  attr_reader :std_material_solarAbsorptance
  attr_reader :std_material_thermalAbsorptance
  attr_reader :std_material_visibleAbsorptance
  attr_reader :std_glazing_material_name
  attr_reader :std_glazing_conductivity
  attr_reader :std_glazing_thermalResistance
  attr_reader :std_glazing_solarTransmittance
  attr_reader :std_glazing_frontSideSolarReflectanceatNormalIncidence 
  attr_reader :std_glazing_backSideSolarReflectanceatNormalIncidence 
  attr_reader :std_glazing_infraredTransmittance
  attr_reader :std_glazing_visibleTransmittanceatNormalIncidence
  attr_reader :std_glazing_frontSideVisibleReflectanceatNormalIncidence
  attr_reader :std_glazing_backSideVisibleReflectanceatNormalIncidence
  attr_reader :std_glazing_frontSideInfraredHemisphericalEmissivity
  attr_reader :std_glazing_backSideInfraredHemisphericalEmissivity
  attr_reader :std_glazing_dirtCorrectionFactorforSolarandVisibleTransmittance


  def initialize
    @std_material_name = Array.new
    @std_material_conductivity = Array.new
    @std_material_density = Array.new
    @std_material_specificHeat = Array.new
    @std_material_solarAbsorptance = Array.new
    @std_material_thermalAbsorptance = Array.new
    @std_material_visibleAbsorptance = Array.new
    @std_glazing_material_name = Array.new
    @std_glazing_conductivity = Array.new
    @std_glazing_thermalResistance = Array.new
    @std_glazing_solarTransmittance = Array.new
    @std_glazing_frontSideSolarReflectanceatNormalIncidence = Array.new
    @std_glazing_backSideSolarReflectanceatNormalIncidence = Array.new
    @std_glazing_infraredTransmittance = Array.new
    @std_glazing_visibleTransmittanceatNormalIncidence = Array.new
    @std_glazing_frontSideVisibleReflectanceatNormalIncidence = Array.new
    @std_glazing_backSideVisibleReflectanceatNormalIncidence = Array.new
    @std_glazing_frontSideInfraredHemisphericalEmissivity = Array.new
    @std_glazing_backSideInfraredHemisphericalEmissivity = Array.new
    @std_glazing_dirtCorrectionFactorforSolarandVisibleTransmittance = Array.new
    @surface_constructions = Array.new
    @sub_surface_constructions = Array.new


  end

  def material_find(model)
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      construction = surface.construction.get
      @surface_constructions << construction.to_Construction.get
    end
    # find name and property for standard opaque material
    @surface_constructions.each do |surface_construction|
      construction_layers = surface_construction.layers
      construction_layers.each do |construction_layer|
        unless construction_layer.to_StandardOpaqueMaterial.empty?
          unless @std_material_name.include?(construction_layer.to_StandardOpaqueMaterial.get.name.to_s)
            @std_material_name << construction_layer.to_StandardOpaqueMaterial.get.name.to_s
            @std_material_conductivity << construction_layer.to_StandardOpaqueMaterial.get.thermalConductivity
            @std_material_density << construction_layer.to_StandardOpaqueMaterial.get.density
            @std_material_specificHeat << construction_layer.to_StandardOpaqueMaterial.get.specificHeat
            @std_material_solarAbsorptance << construction_layer.to_StandardOpaqueMaterial.get.solarAbsorptance
            @std_material_thermalAbsorptance << construction_layer.to_StandardOpaqueMaterial.get.thermalAbsorptance
            @std_material_visibleAbsorptance << construction_layer.to_StandardOpaqueMaterial.get.visibleAbsorptance
          end
        end
      end
    end
    # find name and property for glazing material
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |sub_surface|
      construction = sub_surface.construction.get
      @sub_surface_constructions << construction.to_Construction.get
    end
    @sub_surface_constructions.each do |sub_surface_construction|
      unless sub_surface_construction.layers.empty?
        sub_surface_construction.layers.each do |construction_layer|
          unless construction_layer.to_StandardGlazing.empty?
            unless @std_glazing_material_name.include?(construction_layer.to_StandardGlazing.get.name.to_s)
              @std_glazing_material_name << construction_layer.to_StandardGlazing.get.name.to_s
              @std_glazing_conductivity << construction_layer.to_StandardGlazing.get.thermalConductivity
              @std_glazing_thermalResistance << construction_layer.to_StandardGlazing.get.thermalResistance
              @std_glazing_solarTransmittance << construction_layer.to_StandardGlazing.get.solarTransmittance
              @std_glazing_frontSideSolarReflectanceatNormalIncidence << construction_layer.to_StandardGlazing.get.frontSideSolarReflectanceatNormalIncidence
              @std_glazing_backSideSolarReflectanceatNormalIncidence << construction_layer.to_StandardGlazing.get.backSideSolarReflectanceatNormalIncidence
              @std_glazing_infraredTransmittance << construction_layer.to_StandardGlazing.get.infraredTransmittance
              @std_glazing_visibleTransmittanceatNormalIncidence << construction_layer.to_StandardGlazing.get.infraredTransmittance
              @std_glazing_frontSideVisibleReflectanceatNormalIncidence << construction_layer.to_StandardGlazing.get.frontSideVisibleReflectanceatNormalIncidence
              @std_glazing_backSideVisibleReflectanceatNormalIncidence << construction_layer.to_StandardGlazing.get.backSideVisibleReflectanceatNormalIncidence
              @std_glazing_frontSideInfraredHemisphericalEmissivity << construction_layer.to_StandardGlazing.get.frontSideInfraredHemisphericalEmissivity
              @std_glazing_backSideInfraredHemisphericalEmissivity << construction_layer.to_StandardGlazing.get.backSideInfraredHemisphericalEmissivity
              @std_glazing_dirtCorrectionFactorforSolarandVisibleTransmittance << construction_layer.to_StandardGlazing.get.dirtCorrectionFactorforSolarandVisibleTransmittance
            end
          end
        end
      end
    end
  end

  def material_set(model, parameter_types, parameter_names, parameter_value)
    materials_changed = []
    surface_constructions = []
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      construction = surface.construction.get
      surface_constructions << construction.to_Construction.get
    end
    surface_constructions.each do |surface_construction|
      surface_construction.layers.each do |construction_layer|
        unless construction_layer.to_StandardOpaqueMaterial.empty?
          standard_opaque_material = construction_layer.to_StandardOpaqueMaterial.get
          parameter_types.each_with_index do |type, index|
            unless materials_changed.include?(type + standard_opaque_material.name.to_s)
              if parameter_names[index]== standard_opaque_material.name.to_s
                case type
                  when /Conductivity/
                    standard_opaque_material.setThermalConductivity(parameter_value[index])
                    materials_changed << type + standard_opaque_material.name.to_s
                  when /Density/
                    standard_opaque_material.setDensity(parameter_value[index])
                    materials_changed << type + standard_opaque_material.name.to_s
                  when /SpecificHeat/
                    standard_opaque_material.setSpecificHeat(parameter_value[index])
                    materials_changed << type + standard_opaque_material.name.to_s
                  when /SolarAbsorptance/
                    standard_opaque_material.setSolarAbsorptance(parameter_value[index])
                    materials_changed << type + standard_opaque_material.name.to_s
                  when /ThermalAbsorptance/
                    standard_opaque_material.setThermalAbsorptance(parameter_value[index])
                    materials_changed << type + standard_opaque_material.name.to_s
                  when /VisibleAbsorptance/
                    standard_opaque_material.setVisibleAbsorptance(parameter_value[index])
                    materials_changed << type + standard_opaque_material.name.to_s
                end
                break
              end
            end
          end
        end
      end
    end

    sub_surface_constructions = []
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |sub_surface|
      construction = sub_surface.construction.get
      sub_surface_constructions << construction.to_Construction.get
    end
    sub_surface_constructions.each do |sub_surface_construction|
      construction_layers = sub_surface_construction.layers
      construction_layers.each do |construction_layer|
        unless construction_layer.to_StandardGlazing.empty?
          standard_glazing_material = construction_layer.to_StandardGlazing.get
          parameter_types.each_with_index do |type, index|
            unless materials_changed.include?(type + standard_glazing_material.name.to_s)
              if parameter_names[index] == standard_glazing_material.name.to_s
                case type
                  when /Conductivity/
                    standard_glazing_material.setThermalConductivity(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /ThermalResistance/
                    standard_glazing_material.setThermalResistance(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /SolarTransmittance/
                    standard_glazing_material.setSolarTransmittance(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /FrontSideSolarReflectance/
                    standard_glazing_material.setFrontSideSolarReflectanceatNormalIncidence(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /BackSideSolarReflectance/
                    standard_glazing_material.setBackSideSolarReflectanceatNormalIncidence(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /InfraredTransmittance/
                    standard_glazing_material.setInfraredTransmittance(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /VisibleTransmittance/
                    standard_glazing_material.setVisibleTransmittanceatNormalIncidence(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /FrontSideVisibleReflectance/
                    standard_glazing_material.setFrontSideVisibleReflectanceatNormalIncidence(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /BackSideVisibleReflectance/
                    standard_glazing_material.setBackSideVisibleReflectanceatNormalIncidence(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /FrontSideInfraredHemisphericalEmissivity/
                    standard_glazing_material.setFrontSideVisibleReflectanceatNormalIncidence(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /BackSideInfraredHemisphericalEmissivity/
                    standard_glazing_material.setBackSideInfraredHemisphericalEmissivity(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                  when /DirtCorrectionFactor/
                    standard_glazing_material.setDirtCorrectionFactorforSolarandVisibleTransmittance(parameter_value[index])
                    materials_changed << type + standard_glazing_material.name.to_s
                end
                break
              end
            end
          end
        end
      end
    end
  end

  # Infiltration object is unique at building level
  def infiltration_flow_per_ext_surface_method(model, parameter_types, parameter_names, parameter_value)
    parameter_types.each_with_index do |type, index|
      if parameter_names[index] =~ /FlowPerExteriorArea/
        case type
          when /Infiltration/
            space_infiltration_objects = model.getSpaceInfiltrationDesignFlowRates
            space_infiltration_objects.each do |space_infiltration_object|
              space_infiltration_object.remove
            end
            #loop through spacetypes used in the model adding space infiltration objects
            space_types = model.getSpaceTypes # Space type is required entry to define a thermal space
            space_types.each do |space_type|
              if space_type.spaces.size > 0
                new_space_type_infil = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
                new_space_type_infil.setSpaceType(space_type)
                new_space_type_infil.setFlowperExteriorSurfaceArea(parameter_value[index])
              end
            end
        end
      end
    end
  end

end
	

