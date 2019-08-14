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
# - Created on Feb 27 by Yuming Sun from Argonne National Laboratory

# 1. Introduction
# This function reads simulation results generated in SQL.

require 'openstudio'
require 'fileutils'
require 'rubyXL'
require 'csv'

def sql_table_lookup(in_string, sql_file)
  case in_string
  when /Total Site Energy/
    unless sql_file.totalSiteEnergy.empty?
      table_out = sql_file.totalSiteEnergy.get
    end
  when /Total Source Energy/
    unless sql_file.totalSourceEnergy.empty?
      table_out = sql_file.totalSourceEnergy.get
    end
  when /Electricity Total End Uses/
    unless sql_file.electricityTotalEndUses.empty?
      table_out = sql_file.electricityTotalEndUses.get
    end
  when /Electricity Heating/
    unless sql_file.electricityHeating.empty?
      table_out = sql_file.electricityHeating.get
    end
  when /Electricity Cooling/
    unless sql_file.electricityCooling.empty?
      table_out = sql_file.electricityCooling.get
    end
  when /Electricity Water Systems/
    unless sql_file.electricityWaterSystems.empty?
      table_out = sql_file.electricityWaterSystems.get
    end
  when /Electricity Interior Lighting/
    unless sql_file.electricityInteriorLighting.empty?
      table_out = sql_file.electricityInteriorLighting.get
    end
  when /Electricity Exterior Lighting/
    unless sql_file.electricityExteriorLighting.empty?
      table_out = sql_file.electricityExteriorLighting.get
    end
  when /Electricity Interior Equipment/
    unless sql_file.electricityInteriorEquipment.empty?
      table_out = sql_file.electricityInteriorEquipment.get
    end
  when /Electricity Exterior Equipment/
    unless sql_file.electricityExteriorEquipment.empty?
      table_out = sql_file.electricityExteriorEquipment.get
    end
  when /Electricity Fans/
    unless sql_file.electricityFans.empty?
      table_out = sql_file.electricityFans.get
    end
  when /Electricity Pumps/
    unless sql_file.electricityPumps.empty?
      table_out = sql_file.electricityPumps.get
    end
  when /Electricity Heat Rejection/
    unless sql_file.electricityHeatRejection.empty?
      table_out = sql_file.electricityHeatRejection.get
    end
  when /Natural Gas Total End Uses/
    unless sql_file.naturalGasTotalEndUses.empty?
      table_out = sql_file.naturalGasTotalEndUses.get
    end
  when /Natural Gas Heating/
    unless sql_file.naturalGasHeating.empty?
      table_out = sql_file.naturalGasHeating.get
    end
  when /Natural Gas Cooling/
    unless sql_file.naturalGasCooling.empty?
      table_out = sql_file.naturalGasCooling.get
    end
  when /Natural Gas Water Systems/
    unless sql_file.naturalGasWaterSystems.empty?
      table_out = sql_file.naturalGasWaterSystems.get
    end
  when /District Cooling/
    unless sql_file.districtCoolingCooling.empty?
      table_out = sql_file.districtCoolingCooling.get
    end
  when /District Heating/
    unless sql_file.districtHeatingHeating.empty?
      table_out = sql_file.districtHeatingHeating.get
    end
  when /District Cooling Total End Uses/
    unless sql_file.districtCoolingTotalEndUses.empty?
      table_out = sql_file.districtCoolingTotalEndUses.get
    end
  when /District Heating Total End Uses/
    unless sql_file.districtHeatingTotalEndUses.empty?
      table_out = sql_file.districtHeatingTotalEndUses.get
    end
  else
    abort('Invalid selection of Annual outputs - terminating script')
  end

  return table_out
end

# Module for output postproess
module OutPut
  def self.read(
    sim_dir, setting_file, out_dir, weather = false, verbose = false
  )

    # Output table
    output_table = read_workbook(setting_file, 'TotalEnergy')

    header = Array.new(output_table.length - 1)
    (1..(output_table.length - 1)).each do |output_num|
      header[output_num - 1] = output_table[output_num].to_s[2..-3]
    end

    osm_files = Dir.glob(File.join(sim_dir, '*.osm'))
    num_of_runs = osm_files.length

    sql_paths = []
    osm_files.each do |f|
      sql_paths.push(File.join(f.chomp('.osm'), 'run', 'eplusout.sql'))
    end

    if verbose
      puts "List of SQL files to process in #{sim_dir}"
      puts sql_paths
    end

    data_table = Array.new(num_of_runs) { Array.new(output_table.length - 1) }
    sql_paths.each_with_index do |f, index|
      sql_file = OpenStudio::SqlFile.new(f)
      (1..(output_table.length - 1)).each do |output_num|
        data_table[index][output_num - 1] = sql_table_lookup(
          output_table[output_num].to_s, sql_file
        )
      end
    end

    result_file = File.join(
      out_dir, 'Simulation_Results_Building_Total_Energy.csv'
    )
    CSV.open(result_file, 'wb') do |csv|
      csv << header
      data_table.each do |row|
        csv << row
      end
    end

    if verbose
      puts "Simulation results saved to #{out_dir}/" \
        'Simulation_Results_Building_Total_Energy.csv'
    end

    # Meter table
    meters_table = read_workbook(setting_file, 'Meters')

    (1..(meters_table.length - 1)).each do |meter_index|
      var_value = []

      # Find meters that selected timestep and replace 'Timestep' with 'Zone
      # Timestep' for lookup in SQL
      if meters_table[meter_index][1] == 'Timestep'
        meters_table[meter_index][1] = 'Zone Timestep'
      end

      sql_paths.each do |sql_file_path|
        sql_file = OpenStudio::SqlFile.new(sql_file_path)

        # First look up the EnvironmentPeriorIndex that corresponds to
        # RUN PERIOD 1
        # We need this to ensure we select data for actual weather period
        # run and not the sizing runs
        query_var_index =
          "SELECT EnvironmentPeriodIndex FROM environmentperiods
           WHERE EnvironmentName = 'RUN PERIOD 1'"

        if !sql_file.execAndReturnFirstDouble(query_var_index).empty?
          var_index = sql_file.execAndReturnFirstDouble(query_var_index).get

          # Generate the query for the data from ReportVariableWithTime
          # that has matching meter table name, reporting frequency,
          # and is Run Period 1
          query_var_value =
            "SELECT Value FROM ReportVariableWithTime
             WHERE Name = '#{meters_table[meter_index][0]}'
             AND ReportingFrequency = '#{meters_table[meter_index][1]}'
             AND EnvironmentPeriodIndex = #{var_index}"
          var_value <<
            sql_file.execAndReturnVectorOfDouble(query_var_value).get
        else
          var_value << []
        end
      end

      # Create the first column of header from the meter time step info
      header =
        case meters_table[meter_index][1]
        when /Monthly/
          ['Month']
        when /Daily/
          ['Day']
        when /Hourly/
          ['Hour']
        else
          ['TimeStep']
        end

      # Create the rest of the columns from the simulation number
      (1..num_of_runs).each do |sample_num|
        header << "Sim #{sample_num}"
      end

      meter_names = meters_table[meter_index][0].split(':')
      meter_file = "Meter_#{meter_names[0]}_#{meter_names[1]}.csv"
      CSV.open(File.join(out_dir, meter_file), 'wb') do |csv|
        csv << header
        var_value.transpose.each_with_index do |row, time|
          row.insert(0, time + 1)
          csv << row
        end
        puts "#{meter_file} is saved to the Output folder" if verbose
      end
    end

    return unless weather
    weather_var = []
    sql_file = OpenStudio::SqlFile.new(sql_paths[0])

    # Query dry bulb temperature
    query_var_index =
      "SELECT ReportVariableDataDictionaryIndex
       FROM ReportVariableDataDictionary
       WHERE VariableName = 'Site Outdoor Air Drybulb Temperature'
       AND ReportingFrequency = 'Monthly'"

    if !sql_file.execAndReturnFirstDouble(query_var_index).empty?
      var_index = sql_file.execAndReturnFirstDouble(query_var_index).get
      query_var_value =
        "SELECT VariableValue FROM ReportVariableData
        WHERE ReportVariableDataDictionaryIndex = #{var_index}"
      weather_var << sql_file.execAndReturnVectorOfDouble(query_var_value).get
    else
      weather_var << []
    end

    # Query horizontal solar irradiation
    query_var_index =
      "SELECT ReportVariableDataDictionaryIndex
       FROM ReportVariableDataDictionary
       WHERE VariableName =
        'Site Ground Reflected Solar Radiation Rate per Area'
       AND ReportingFrequency = 'Monthly'"

    if !sql_file.execAndReturnFirstDouble(query_var_index).empty?
      var_index = sql_file.execAndReturnFirstDouble(query_var_index).get
      query_var_value =
        "SELECT VariableValue FROM ReportVariableData
        WHERE ReportVariableDataDictionaryIndex = #{var_index}"
      ground_reflec_solar =
        sql_file.execAndReturnVectorOfDouble(query_var_value).get
      horizontal_total_solar = ground_reflec_solar.collect { |n| n * 5 }
      weather_var << horizontal_total_solar
    else
      weather_var << []
    end

    weather_out = weather_var.transpose * num_of_runs

    CSV.open(File.join(out_dir, 'Monthly_Weather.csv'), 'wb') do |csv|
      csv << ['Monthly DryBuld Temp [C]', 'Monthly Horizontal Solar [W/m^2]']
      weather_out.each { |row| csv << row }
    end
  end
end
