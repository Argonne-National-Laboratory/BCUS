# Copyright © 2019 , UChicago Argonne, LLC
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
#       "This product includes software produced by UChicago Argonne, LLC under
#       Contract No. DE-AC02-06CH11357 with the Department of Energy."

# ******************************************************************************
# DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY
# FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA,
# APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT
# INFRINGE PRIVATELY OWNED RIGHTS.

# ******************************************************************************

# Modified Date and By:
# - Created on Feb 27 by Yuming Sun from Argonne National Laboratory

# 1. Introduction
# This function reads simulation results generated in SQL.

require 'openstudio'
require 'fileutils'
require 'rubyXL'
require 'csv'

# Module for output postproess
module OutPut
  def self.read(sql_file_path, meter_set_file, output_folder)
    # Find the path of sql
    workbook =
      RubyXL::Parser.parse(meter_set_file)
    # output_table = workbook['TotalEnergy'].extract_data  outdated by June 28th

    output_table = []
    output_table_row = []
    workbook['TotalEnergy'].each do |row|
      output_table_row = []
      row.cells.each { |cell| output_table_row.push(cell.value) }
      output_table.push(output_table_row)
    end

    total_site_energy = []
    total_source_energy = []
    electricity_total_end_uses = []
    electricity_heating = []
    electricity_cooling = []
    electricity_water_systems = []
    electricity_interior_lighting = []
    electricity_exterior_lighting = []
    electricity_interior_equipment = []
    electricity_exterior_equipment = []
    electricity_fans = []
    electricity_pumps = []
    electricity_heat_rejection = []
    natural_gas_total_end_uses = []
    natural_gas_heating = []
    natural_gas_cooling = []
    natural_gas_water_systems = []
    district_cooling = []
    district_heating = []
    district_cooling_total_end_uses = []
    district_heating_total_end_uses = []

    sql_file = OpenStudio::SqlFile.new(sql_file_path)
    (1..(output_table.length - 1)).each do |output_num|
      case output_table[output_num].to_s
      when /Total Site Energy/
        total_site_energy <<
          if !sql_file.totalSiteEnergy.empty?
            sql_file.totalSiteEnergy.get
          else
            ''
          end
      when /Total Source Energy/
        total_source_energy <<
          if !sql_file.totalSourceEnergy.empty?
            sql_file.totalSourceEnergy.get
          else
            ''
          end
      when /Electricity Total End Uses/
        electricity_total_end_uses <<
          if !sql_file.electricityTotalEndUses.empty?
            sql_file.electricityTotalEndUses.get
          else
            ''
          end
      when /Electricity Heating/
        electricity_heating <<
          if sql_file.electricityHeating.empty?
            sql_file.electricityHeating.get
          else
            ''
          end
      when /Electricity Cooling/
        electricity_cooling <<
          if !sql_file.electricityCooling.empty?
            sql_file.electricityCooling.get
          else
            ''
          end
      when /Electricity Water Systems/
        electricity_water_systems <<
          if !sql_file.electricityWaterSystems.empty?
            sql_file.electricityWaterSystems.get
          else
            ''
          end
      when /Electricity Interior Lighting/
        electricity_interior_lighting <<
          if !sql_file.electricityInteriorLighting.empty?
            sql_file.electricityInteriorLighting.get
          else
            ''
          end
      when /Electricity Exterior Lighting/
        electricity_exterior_lighting <<
          if !sql_file.electricityExteriorLighting.empty?
            sql_file.electricityExteriorLighting.get
          else
            ''
          end
      when /Electricity Interior Equipment/
        electricity_interior_equipment <<
          if !sql_file.electricityInteriorEquipment.empty?
            sql_file.electricityInteriorEquipment.get
          else
            ''
          end
      when /Electricity Exterior Equipment/
        electricity_exterior_equipment <<
          if !sql_file.electricityExteriorEquipment.empty?
            sql_file.electricityExteriorEquipment.get
          else
            ''
          end
      when /Electricity Fans/
        electricity_fans <<
          if !sql_file.electricityFans.empty?
            sql_file.electricityFans.get
          else
            ''
          end
      when /Electricity Pumps/
        electricity_pumps <<
          if !sql_file.electricityPumps.empty?
            sql_file.electricityPumps.get
          else
            ''
          end
      when /Electricity Heat Rejection/
        electricity_heat_rejection <<
          if !sql_file.electricityHeatRejection.empty?
            sql_file.electricityHeatRejection.get
          else
            ''
          end
      when /Natural Gas Total End Uses/
        natural_gas_total_end_uses <<
          if !sql_file.naturalGasTotalEndUses.empty?
            sql_file.naturalGasTotalEndUses.get
          else
            ''
          end
      when /Natural Gas Heating/
        natural_gas_heating <<
          if !sql_file.naturalGasHeating.empty?
            sql_file.naturalGasHeating.get
          else
            ''
          end
      when /Natural Gas Cooling/
        natural_gas_cooling <<
          if !sql_file.naturalGasCooling.empty?
            sql_file.naturalGasCooling.get
          else
            ''
          end
      when /Natural Gas Water Systems/
        natural_gas_water_systems <<
          if !sql_file.naturalGasWaterSystems.empty?
            sql_file.naturalGasWaterSystems.get
          else
            ''
          end
      when /District Cooling/
        district_cooling <<
          if !sql_file.districtCoolingCooling.empty?
            sql_file.districtCoolingCooling.get
          else
            ''
          end
      when /District Heating/
        district_heating <<
          if !sql_file.districtHeatingHeating.empty?
            sql_file.districtHeatingHeating.get
          else
            ''
          end
      when /District Cooling Total End Uses/
        district_cooling_total_end_uses <<
          if !sql_file.districtCoolingTotalEndUses.empty?
            sql_file.districtCoolingTotalEndUses.get
          else
            ''
          end
      when /District Heating Total End Uses/
        district_heating_total_end_uses <<
          if !sql_file.districtHeatingTotalEndUses.empty?
            sql_file.districtHeatingTotalEndUses.get
          else
            ''
          end
      end
    end

    # Put all output array to final_output
    final_output = []
    header = []
    (1..(output_table.length - 1)).each do |output_num|
      case output_table[output_num].to_s
      when /Total Site Energy/
        final_output << total_site_energy
        header << 'Total Site Energy [GJ]'
      when /Total Source Energy/
        final_output << total_source_energy
        header << 'Total Source Energy [GJ]'
      when /Electricity Total End Uses/
        final_output << electricity_total_end_uses
        header << 'Electricity Total End Uses [GJ]'
      when /Electricity Heating/
        final_output << electricity_heating
        header << 'Electricity Heating [GJ]'
      when /Electricity Cooling/
        final_output << electricity_cooling
        header << 'Electricity Cooling [GJ]'
      when /Electricity Water Systems/
        final_output << electricity_water_systems
        header << 'Electricity Water Systems [GJ]'
      when /Electricity Interior Lighting/
        final_output << electricity_interior_lighting
        header << 'Electricity Interior Lighting [GJ]'
      when /Electricity Exterior Lighting/
        final_output << electricity_exterior_lighting
        header << 'Electricity Exterior Lighting [GJ]'
      when /Electricity Interior Equipment/
        final_output << electricity_interior_equipment
        header << 'Electricity Interior Equipment [GJ]'
      when /Electricity Exterior Equipment/
        final_output << electricity_exterior_equipment
        header << 'Electricity Exterior Equipment [GJ]'
      when /Electricity Fans/
        final_output << electricity_fans
        header << 'Electricity Fans [GJ]'
      when /Electricity Pumps/
        final_output << electricity_pumps
        header << 'Electricity Pumps [GJ]'
      when /Electricity Heat Rejection/
        final_output << electricity_heat_rejection
        header << 'Electricity Heat Rejection [GJ]'
      when /Natural Gas Total End Uses/
        final_output << natural_gas_total_end_uses
        header << 'Natural Gas Total End Uses [GJ]'
      when /Natural Gas Heating/
        final_output << natural_gas_heating
        header << 'Natural Gas Heating [GJ]'
      when /Natural Gas Cooling/
        final_output << natural_gas_cooling
        header << 'Natural Gas Cooling [GJ]'
      when /Natural Gas Water Systems/
        final_output << natural_gas_water_systems
        header << 'Natural Gas Water Systems [GJ]'
      when /District Cooling/
        final_output << district_cooling
        header << 'District Cooling [GJ]'
      when /District Heating/
        final_output << district_heating
        header << 'District Heating [GJ]'
      when /District Cooling Total End Uses/
        final_output << district_cooling_total_end_uses
        header << 'District Cooling Total End Uses [GJ]'
      when /District Heating Total End Uses/
        final_output << district_heating_total_end_uses
        header << 'District Heating Total End Uses [GJ]'
      end
    end

    # Save to final_output to csv files
    table = final_output.transpose
    CSV.open(
      "#{output_folder}/Simulation_Results_Building_Total_Energy.csv", 'wb'
    ) do |csv|
      csv << header
    end

    CSV.open(
      "#{output_folder}/Simulation_Results_Building_Total_Energy.csv", 'a+'
    ) do |csv|
      table.each { |row| csv << row }
    end

    workbook = RubyXL::Parser.parse(meter_set_file)
    # meters_table = workbook['Meters'].extract_data  outdated by June 28th
    meters_table = []
    meters_table_row = []
    workbook['Meters'].each do |row|
      meters_table_row = []
      row.cells.each { |cell| meters_table_row.push(cell.value) }
      meters_table.push(meters_table_row)
    end

    (1..(meters_table.length - 1)).each do |meter_index|
      var_value = []
      sql_file = OpenStudio::SqlFile.new(sql_file_path)
      query_var_index =
        "SELECT ReportMeterDataDictionaryIndex FROM ReportMeterDataDictionary
          WHERE VariableName = '#{meters_table[meter_index][0]}'
          AND ReportingFrequency = '#{meters_table[meter_index][1]}'"
      if !sql_file.execAndReturnFirstDouble(query_var_index).empty?
        var_index = sql_file.execAndReturnFirstDouble(query_var_index).get
        query_var_value = "SELECT VariableValue FROM ReportMeterData
          WHERE ReportMeterDataDictionaryIndex = #{var_index}"
        var_value << sql_file.execAndReturnVectorOfDouble(query_var_value).get
      else
        var_value << []
      end

      header =
        case meters_table[meter_index][1]
        when /Monthly/
          %w[Jan Feb Mar April May June July Aug Sept Oct Nov Dec]
        when /Daily/
          ['Day 1', 'Day 2', 'Day 3', '...']
        when /Hourly/
          ['Hour 1', 'Hour 2', 'Hour 3', '...']
        else
          ['TimeStep 1', 'TimeStep 2', 'TimeStep 3', '...']
        end

      CSV.open(
        "#{output_folder}/" \
        "Meter_#{meters_table[meter_index][0].split(':')[0]}_" \
        "#{meters_table[meter_index][0].split(':')[1]}.csv",
        'wb'
      ) do |csv|
        csv << header
      end

      CSV.open(
        "#{output_folder}/" \
        "Meter_#{meters_table[meter_index][0].split(':')[0]}_" \
        "#{meters_table[meter_index][0].split(':')[1]}.csv",
        'a+'
      ) do |csv|
        var_value.each { |row| csv << row }
      end
    end
  end
end
