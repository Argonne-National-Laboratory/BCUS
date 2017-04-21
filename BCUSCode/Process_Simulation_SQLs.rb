# Copyright © 2016 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.  Software changes,
#    modifications, or derivative works, should be noted with comments and the
#    author and organization’s name.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor
#    the names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# 4. The software and the end-user documentation included with the
#    redistribution, if any, must include the following acknowledgment:
#
#    "This product includes software produced by UChicago Argonne, LLC under
#     Contract No. DE-AC02-06CH11357 with the Department of Energy.”
#
# *****************************************************************************
# DISCLAIMER
#
# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.
#
# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF
# ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY
# WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR
# RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY
# INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS
# THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
#
# *****************************************************************************

# Modified Date and By:
# - Created on Feb 27 by Yuming Sun from Argonne National Laboratory
# 07-Apr-2017 Ralph Muehleisen, Updated to work with OS 1.14, change output
# file format, and clean up code
# 15-Apr-2017 Ralph Muehleisen Updated to work for one or more than one OSM to
# analyze and cleaned up code

# 1. Introduction
# This function reads simulation results generated in SQL.

require 'openstudio'
require 'fileutils'
require 'rubyXL'
require 'csv'

#
def sql_table_lookup(inString, sqlFile)
  case inString
  when /Total Site Energy/
    table_out = sqlFile.totalSiteEnergy.get unless sqlFile.totalSiteEnergy.empty?
  when /Total Source Energy/
    table_out = sqlFile.totalSourceEnergy.get unless sqlFile.totalSourceEnergy.empty?
  when /Electricity Total End Uses/
    table_out = sqlFile.electricityTotalEndUses.get unless sqlFile.electricityTotalEndUses.empty?
  when /Electricity Heating/
    table_out = sqlFile.electricityHeating.get unless sqlFile.electricityHeating.empty?
  when /Electricity Cooling/
    table_out = sqlFile.electricityCooling.get unless sqlFile.electricityCooling.empty?
  when /Electricity Water Systems/
    table_out = sqlFile.electricityWaterSystems.get unless sqlFile.electricityWaterSystems.empty?
  when /Electricity Interior Lighting/
    table_out = sqlFile.electricityInteriorLighting.get unless sqlFile.electricityInteriorLighting.empty?
  when /Electricity Exterior Lighting/
    table_out = sqlFile.electricityExteriorLighting.get unless sqlFile.electricityExteriorLighting.empty?
  when /Electricity Interior Equipment/
    table_out = sqlFile.electricityInteriorEquipment.get unless sqlFile.electricityInteriorEquipment.empty?
  when /Electricity Exterior Equipment/
    table_out = sqlFile.electricityExteriorEquipment.get unless sqlFile.electricityExteriorEquipment.empty?
  when /Electricity Fans/
    table_out = sqlFile.electricityFans.get unless sqlFile.electricityFans.empty?
  when /Electricity Pumps/
    dtable_out = sqlFile.electricityPumps.get unless sqlFile.electricityPumps.empty?
  when /Electricity Heat Rejection/
    table_out = sqlFile.electricityHeatRejection.get unless sqlFile.electricityHeatRejection.empty?
  when /Natural Gas Total End Uses/
    table_out = sqlFile.naturalGasTotalEndUses.get unless sqlFile.naturalGasTotalEndUses.empty?
  when /Natural Gas Heating/
    table_out = sqlFile.naturalGasHeating.get unless sqlFile.naturalGasHeating.empty?
  when /Natural Gas Cooling/
    table_out = sqlFile.naturalGasCooling.get unless sqlFile.naturalGasCooling.empty?
  when /Natural Gas Water Systems/
    table_out = sqlFile.naturalGasWaterSystems.get unless sqlFile.naturalGasWaterSystems.empty?
  when /District Cooling/
    table_out = sqlFile.districtCoolingCooling.get unless sqlFile.districtCoolingCooling.empty?
  when /District Heating/
    table_out = sqlFile.districtHeatingHeating.get unless sqlFile.districtHeatingHeating.empty?
  when /District Cooling Total End Uses/
    table_out = sqlFile.districtCoolingTotalEndUses.get unless sqlFile.districtCoolingTotalEndUses.empty?
  when /District Heating Total End Uses/
    table_out = sqlFile.districtHeatingTotalEndUses.get unless sqlFile.districtHeatingTotalEndUses.empty?
  else
    abort('Invalid selection of Annual outputs - terminating script')
  end

  table_out
end

module OutPut
  # def OutPut.Read(num_of_runs, project_path, out_prefix, settingsfile, verbose=false)
  def self.Read(simulations_folder, output_folder, settingsfile, verbose = false)
    # simulations_folder = "#{project_path}/UA_Simulations"
    # output_folder = "#{project_path}/UA_Output"
    # create a workbook to read in the simulation output settings file
    workbook = RubyXL::Parser.parse(settingsfile)

    output_table = []
    # find all the total energy tables requested in the simulation output settings file

    workbook['TotalEnergy'].each do |row|
      output_table_row = []
      row.cells.each do |cell|
        output_table_row.push(cell.value)
      end
      output_table.push(output_table_row)
    end

    # get the header string from output_table and remove the leading "[" and trailing "]"
    header = Array.new(output_table.length - 1)
    (1..(output_table.length - 1)).each do |output_num|
      header[output_num - 1] = output_table[output_num].to_s[2..-3]
    end

    osmFiles = Dir.glob("#{simulations_folder}/*.osm")
    num_of_runs = osmFiles.length

    sqlFiles = []
    osmFiles.each do |f|
      sqlFiles << "#{f.chomp('.osm')}/ModelToIDF/EnergyPlus-0/eplusout.sql"
    end

    data_table = Array.new(num_of_runs) { Array.new(output_table.length - 1) }

    if verbose
      puts "List of SQL files to process in #{simulations_folder}"
      puts sqlFiles
    end

    sqlFiles.each_with_index do |f, index|
      sqlFile = OpenStudio::SqlFile.new(f)
      (1..(output_table.length - 1)).each do |output_num|
        data_table[index][output_num - 1] = sql_table_lookup(output_table[output_num].to_s, sqlFile)
      end
    end

    CSV.open("#{output_folder}/Simulation_Results_Building_Total_Energy.csv", 'wb') do |csv|
      csv << header
    end

    CSV.open("#{output_folder}/Simulation_Results_Building_Total_Energy.csv", 'a+') do |csv|
      data_table.each do |row|
        csv << row
      end
    end

    puts "Simulation results saved to #{output_folder}/Simulation_Results_Building_Total_Energy.csv" if verbose

    # look for all the requested meters using the same workbook as above
    meters_table = []
    workbook['Meters'].each do |row|
      meters_table_row = []
      row.cells.each do |cell|
        meters_table_row.push(cell.value)
      end
      meters_table.push(meters_table_row)
    end

    # loop through all the found meters and extract their data from the SQL file
    (1..(meters_table.length - 1)).each do |meter_index|
      var_value = []

      # find meters that selected timestep and replace 'Timestep' with 'Zone Timestep' for lookup in SQL
      if meters_table[meter_index][1] == 'Timestep'
        meters_table[meter_index][1] = 'Zone Timestep'
      end

      sqlFiles.each do |f|
        sqlFile = OpenStudio::SqlFile.new(f)
        # first look up the EnvironmentPeriorIndex that corresponds to RUN PERIOD 1
        # we need this to make sure we only select data for actual weather period run and not the sizing runs
        query_var_index = "SELECT EnvironmentPeriodIndex FROM environmentperiods
                            WHERE EnvironmentName = 'RUN PERIOD 1'"
        if sqlFile.execAndReturnFirstDouble(query_var_index).empty?
          var_value << []
        else
          var_index = sqlFile.execAndReturnFirstDouble(query_var_index).get

          # generate the query for the data from ReportVariableWithTime that has matching
          # meter table name, reporting frequency, and is Run Period 1
          query_var_value = "SELECT Value FROM ReportVariableWithTime
           WHERE Name = '#{meters_table[meter_index][0]}' AND
           ReportingFrequency = '#{meters_table[meter_index][1]}' AND
           EnvironmentPeriodIndex = #{var_index}"

          var_value << sqlFile.execAndReturnVectorOfDouble(query_var_value).get
        end
      end

      # create the first column of header from the meter time step info
      header = case meters_table[meter_index][1]
               when /Monthly/
                 ['Month']
               when /Daily/
                 ['Day']
               when /Hourly/
                 ['Hour']
               else
                 ['TimeStep']
               end

      # create the rest of the columns from the simulation number
      (1..num_of_runs).each do |sample_num|
        header << "Sim #{sample_num}"
      end

      csv_metername = "Meter_#{meters_table[meter_index][0].split(':')[0]}_#{meters_table[meter_index][0].split(':')[1]}"
      csv_filename = "#{output_folder}/" + csv_metername + '.csv'

      CSV.open(csv_filename, 'wb') do |csv|
        csv << header
        var_value.transpose.each_with_index do |row, time|
          row.insert(0, time + 1)
          csv << row
        end
        puts "#{csv_metername} is saved to the Output folder" if verbose
      end
    end

    weather_var = []
    sqlFile = OpenStudio::SqlFile.new(sqlFiles[0])

    query_var_index = "SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary
           WHERE VariableName = 'Site Outdoor Air Drybulb Temperature' AND
           ReportingFrequency = 'Monthly'"

    if sqlFile.execAndReturnFirstDouble(query_var_index).empty?
      weather_var << []
    else
      var_index = sqlFile.execAndReturnFirstDouble(query_var_index).get
      query_var_value = "SELECT VariableValue FROM ReportVariableData
           WHERE ReportVariableDataDictionaryIndex = #{var_index}"
      weather_var << sqlFile.execAndReturnVectorOfDouble(query_var_value).get
    end

    # Query Horizontal Solar Irradiation
    query_var_index = "SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary
           WHERE VariableName = 'Site Ground Reflected Solar Radiation Rate per Area' AND
           ReportingFrequency = 'Monthly'"

    if sqlFile.execAndReturnFirstDouble(query_var_index).empty?
      weather_var << []
    else
      var_index = sqlFile.execAndReturnFirstDouble(query_var_index).get

      query_var_value = "SELECT VariableValue FROM ReportVariableData
           WHERE ReportVariableDataDictionaryIndex = #{var_index}"
      ground_reflec_solar = sqlFile.execAndReturnVectorOfDouble(query_var_value).get
      horizontal_total_solar = ground_reflec_solar.collect { |n| n * 5 }
      weather_var << horizontal_total_solar
    end

    weather_out = weather_var.transpose * num_of_runs

    CSV.open("#{output_folder}/Monthly_Weather.csv", 'wb') do |csv|
      csv << ['Monthly DryBuld Temp [C]', 'Monthly Horizontal Solar [W/m^2]']
      weather_out.each do |row|
        csv << row
      end
    end
  end #  OutPut.Read
end # Module Output
