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
# - Updated on Junly 2016 by Yuna Zhang from Argonne National Laboratory
# - Updated on June 2015 by Yuna Zhang from Argonne National Laboratory
# - Created on March 2015 by Yuming Sun from Argonne National Laboratory

# 1. Introduction
# This is the subfunction called by uncertain_parameters to generate
# envelop uncertainty distribution.

# Class to describe envelop material property uncertainty
class EnvelopUncertainty < OpenStudio::Model::Model
  attr_reader :std_mat_name
  attr_reader :std_mat_conductivity
  attr_reader :std_mat_density
  attr_reader :std_mat_specificHeat
  attr_reader :std_mat_solarAbsorptance
  attr_reader :std_mat_thermalAbsorptance
  attr_reader :std_mat_visibleAbsorptance
  attr_reader :std_glz_name
  attr_reader :std_glz_conductivity
  attr_reader :std_glz_thermalResistance
  attr_reader :std_glz_solarTransmittance
  attr_reader :std_glz_front_solarReflectance
  attr_reader :std_glz_back_solarReflectance
  attr_reader :std_glz_infraredTransmittance
  attr_reader :std_glz_visibleTransmittance
  attr_reader :std_glz_front_visibleReflectance
  attr_reader :std_glz_back_visibleReflectance
  attr_reader :std_glz_front_infraredEmissivity
  attr_reader :std_glz_back_infraredEmissivity
  attr_reader :std_glz_dirtCorrectionFactor

  def initialize
    # rubocop:disable Naming/VariableName
    @std_mat_name = []
    @std_mat_conductivity = []
    @std_mat_density = []
    @std_mat_specificHeat = []
    @std_mat_solarAbsorptance = []
    @std_mat_thermalAbsorptance = []
    @std_mat_visibleAbsorptance = []
    @std_glz_name = []
    @std_glz_conductivity = []
    @std_glz_thermalResistance = []
    @std_glz_solarTransmittance = []
    @std_glz_front_solarReflectance = []
    @std_glz_back_solarReflectance = []
    @std_glz_infraredTransmittance = []
    @std_glz_visibleTransmittance = []
    @std_glz_front_visibleReflectance = []
    @std_glz_back_visibleReflectance = []
    @std_glz_front_infraredEmissivity = []
    @std_glz_back_infraredEmissivity = []
    @std_glz_dirtCorrectionFactor = []
    @surface_constructions = []
    @sub_surface_constructions = []
    # rubocop:enable Naming/VariableName
  end

  def material_find(model)
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      construction = surface.construction.get
      @surface_constructions << construction.to_Construction.get
    end

    # Find name and property for standard opaque material
    @surface_constructions.each do |surface_construction|
      construction_layers = surface_construction.layers
      construction_layers.each do |construction_layer|
        next if construction_layer.to_StandardOpaqueMaterial.empty?
        next if @std_mat_name.include?(
          construction_layer.to_StandardOpaqueMaterial.get.name.to_s
        )
        @std_mat_name <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.name.to_s
        @std_mat_conductivity <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.thermalConductivity
        @std_mat_density <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.density
        @std_mat_specificHeat <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.specificHeat
        @std_mat_solarAbsorptance <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.solarAbsorptance
        @std_mat_thermalAbsorptance <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.thermalAbsorptance
        @std_mat_visibleAbsorptance <<
          construction_layer.to_StandardOpaqueMaterial
                            .get.visibleAbsorptance
      end
    end

    # Find name and property for glazing material
    sub_surfaces = model.getSubSurfaces
    sub_surfaces.each do |sub_surface|
      construction = sub_surface.construction.get
      @sub_surface_constructions << construction.to_Construction.get
    end
    @sub_surface_constructions.each do |sub_surface_construction|
      next if sub_surface_construction.layers.empty?
      sub_surface_construction.layers.each do |construction_layer|
        next if construction_layer.to_StandardGlazing.empty?
        next if @std_glz_name.include?(
          construction_layer.to_StandardGlazing.get.name.to_s
        )
        # rubocop:disable Metrics/LineLength
        @std_glz_name <<
          construction_layer.to_StandardGlazing
                            .get.name.to_s
        @std_glz_conductivity <<
          construction_layer.to_StandardGlazing
                            .get.thermalConductivity
        @std_glz_thermalResistance <<
          construction_layer.to_StandardGlazing
                            .get.thermalResistance
        @std_glz_solarTransmittance <<
          construction_layer.to_StandardGlazing
                            .get.solarTransmittance
        @std_glz_front_solarReflectance <<
          construction_layer.to_StandardGlazing
                            .get.frontSideSolarReflectanceatNormalIncidence
        @std_glz_back_solarReflectance <<
          construction_layer.to_StandardGlazing
                            .get.backSideSolarReflectanceatNormalIncidence
        @std_glz_infraredTransmittance <<
          construction_layer.to_StandardGlazing
                            .get.infraredTransmittance
        @std_glz_visibleTransmittance <<
          construction_layer.to_StandardGlazing
                            .get.infraredTransmittance
        @std_glz_front_visibleReflectance <<
          construction_layer.to_StandardGlazing
                            .get.frontSideVisibleReflectanceatNormalIncidence
        @std_glz_back_visibleReflectance <<
          construction_layer.to_StandardGlazing
                            .get.backSideVisibleReflectanceatNormalIncidence
        @std_glz_front_infraredEmissivity <<
          construction_layer.to_StandardGlazing
                            .get.frontSideInfraredHemisphericalEmissivity
        @std_glz_back_infraredEmissivity <<
          construction_layer.to_StandardGlazing
                            .get.backSideInfraredHemisphericalEmissivity
        @std_glz_dirtCorrectionFactor <<
          construction_layer.to_StandardGlazing
                            .get.dirtCorrectionFactorforSolarandVisibleTransmittance
        # rubocop:enable Metrics/LineLength
      end
    end
  end

  def material_set(model, param_types, param_names, param_values)
    materials_changed = []
    surface_constructions = []
    surfaces = model.getSurfaces
    surfaces.each do |surface|
      construction = surface.construction.get
      surface_constructions << construction.to_Construction.get
    end
    surface_constructions.each do |surface_construction|
      surface_construction.layers.each do |construction_layer|
        next if construction_layer.to_StandardOpaqueMaterial.empty?
        standard_opaque_material =
          construction_layer.to_StandardOpaqueMaterial.get
        param_types.each_with_index do |type, index|
          next if materials_changed.include?(
            type + standard_opaque_material.name.to_s
          )
          next unless param_names[index] == standard_opaque_material.name.to_s
          param_set =
            case type
            when /Conductivity/
              'setThermalConductivity'
            when /Density/
              'setDensity'
            when /SpecificHeat/
              'setSpecificHeat'
            when /SolarAbsorptance/
              'setSolarAbsorptance'
            when /ThermalAbsorptance/
              'setThermalAbsorptance'
            when /VisibleAbsorptance/
              'setVisibleAbsorptance'
            end
          next if param_set.nil?
          standard_opaque_material.send(
            param_set.to_sym, param_values[index]
          )
          materials_changed <<
            type + standard_opaque_material.name.to_s
          break
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
        next if construction_layer.to_StandardGlazing.empty?
        standard_glazing_material = construction_layer.to_StandardGlazing.get
        param_types.each_with_index do |type, index|
          next if materials_changed.include?(
            type + standard_glazing_material.name.to_s
          )
          next unless param_names[index] == standard_glazing_material.name.to_s
          param_set =
            case type
            when /Conductivity/
              'setThermalConductivity'
            when /ThermalResistance/
              'setThermalResistance'
            when /SolarTransmittance/
              'setSolarTransmittance'
            when /FrontSideSolarReflectance/
              'setFrontSideSolarReflectanceatNormalIncidence'
            when /BackSideSolarReflectance/
              'setBackSideSolarReflectanceatNormalIncidence'
            when /InfraredTransmittance/
              'setInfraredTransmittance'
            when /VisibleTransmittance/
              'setVisibleTransmittanceatNormalIncidence'
            when /FrontSideVisibleReflectance/
              'setFrontSideVisibleReflectanceatNormalIncidence'
            when /BackSideVisibleReflectance/
              'setBackSideVisibleReflectanceatNormalIncidence'
            when /FrontSideInfraredHemisphericalEmissivity/
              'setFrontSideVisibleReflectanceatNormalIncidence'
            when /BackSideInfraredHemisphericalEmissivity/
              'setBackSideInfraredHemisphericalEmissivity'
            when /DirtCorrectionFactor/
              'setDirtCorrectionFactorforSolarandVisibleTransmittance'
            end
          next if param_set.nil?
          standard_glazing_material.send(
            param_set.to_sym, param_values[index]
          )
          materials_changed <<
            type + standard_glazing_material.name.to_s
          break
        end
      end
    end
  end

  # Infiltration object is unique at building level
  def infiltration_flow_per_ext_surface_set(
    model, param_types, param_names, param_values
  )
    param_types.each_with_index do |type, index|
      next unless param_names[index] =~ /FlowPerExteriorArea/
      case type
      when /Infiltration/
        space_infiltration_objects =
          model.getSpaceInfiltrationDesignFlowRates
        space_infiltration_objects.each(&:remove)
        # Loop through spacetypes used in the model adding
        # space infiltration objects
        # Space type is required entry to define a thermal space
        space_types = model.getSpaceTypes
        space_types.each do |space_type|
          next if space_type.spaces.empty?
          new_space_type_infil =
            OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
          new_space_type_infil.setSpaceType(space_type)
          new_space_type_infil.setFlowperExteriorSurfaceArea(
            param_values[index]
          )
        end
      end
    end
  end
end
