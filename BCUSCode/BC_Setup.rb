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
# - August 2016 by Yuna Zhang
# - Created on February 15 2015 by Yuming Sun from Argonne National Laboratory
#
# 08-Apr-2017 Ralph Muehleisen updated require_relative from LSH_Gen to LHS_Morris
# 08-Apr-2017 Ralph Muehleisen add --noEP option to parser to avoid running EnergyPlus if the prerun files exist
# 15-Apr-2017 Ralph Muehleisen converted code to read new columnar output of simulation meter files
# 21-Apr-2017 RTM ran rubocop linter for code cleanup

# 1. Introduction
# This is the main code used for setting up files for running Bayesian calibration.

#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for setting up files for running Bayesian calibration
#

require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
# require_relative 'LHS_Gen'
require_relative 'LHS_Morris'
require_relative 'Process_Simulation_SQLs'
require_relative 'rinruby'

require 'openstudio'
require 'optparse'
require 'fileutils'
require 'csv'
require 'rubyXL'

def writeToFile(results, filename, verbose = false)
  File.open(filename, 'w+') do |f|
    for resultsRow in results
      for r in resultsRow
        f.write(r)
        f.write("\t")
      end
      f.write("\n")
    end
  end
  puts "Run results have been written to #{filename}" if verbose
end

# ARGV = ["../Install/test.osm", "../Install/test.epw", "-v","-n","-s ../Install/Simulation_Output_Settings.xlsx"]
# parse commandline inputs from the user
options = { osmName: nil, epwName: nil }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: PreRuns_Calibration.rb [options]'

  opts.on('--osmName osmName', 'osmName') do |osmName|
    options[:osmName] = osmName
  end

  opts.on('--epwName epwName', 'epwName') do |epwName|
    options[:epwName] = epwName
  end

  # options[:outFile] = 'Simulation_Output_Settings.xlsx'
  # opts.on('-o', '--outfile outFile', 'Simulation Output Setting File (default=Simulation_Output_Settings.xlsx)') do |outFile|
  # options[:outFile] = outFile
  # end

  options[:settingsFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-s', '--settingsfile outFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |settingsFile|
    options[:settingsFile] = settingsFile
  end

  options[:priorsFile] = 'priors.csv'
  opts.on('--priors priorsFile', 'CSV File with prior uncertainty distribution info (default=priors.csv)') do |priorsFile|
    options[:priorsFile] = priorsFile
  end

  options[:utilityData] = 'utilitydata.csv'
  opts.on('--utilityData utilityData', 'CSV File with utility data (default=utilitydata.csv)') do |utilityData|
    options[:utilityData] = utilityData
  end

  options[:numLHS] = 100
  opts.on('--numLHS numLHS', 'Number of LHS points (default = 100)') do |numLHS|
    options[:numLHS] = numLHS
  end

  options[:randseed] = 0
  opts.on('--seed seednum', 'Integer random number seed, 0 = no seed, default = 0') do |seednum|
    options[:randseed] = seednum
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end

  options[:verbose] = false
  opts.on('-v', '--verbose', 'Run in verbose mode with more output info printed') do
    options[:verbose] = true
  end

  options[:noep] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noEP] = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

parser.parse!

# if the user didn't give the --osmName option, parse the rest of the input arguments for a *.osm
if options[:osmName].nil?
  if ARGV.grep(/.osm/).any?
    temp = ARGV.grep /.osm/
    osm_name = temp[0]
  else
    puts 'An OpenStudio OSM file must be indicated by the --osmNAME option or giving a filename ending with .osm on the command line'
    abort
  end
else # otherwise the --osmName option was used
  osm_name = options[:osmName]
end

# if the user didn't give the --epwName option, parse the rest of the input arguments for a *.epw
if options[:epwName].nil?
  if ARGV.grep(/.epw/).any?
    temp = ARGV.grep /.epw/
    epw_name = temp[0]
  else
    puts 'An .epw weather file must be indicated by the --epwNAME option or giving a filename ending with .epw on the command line'
    abort
  end
else # otherwise the --epwName option was used
  epw_name = options[:epwName]
end

outfile_name = options[:outFile]
outfile_name = options[:settingsFile]
settingsfile_name = options[:settingsFile]
priors_name = options[:priorsFile]
num_of_runs = Integer(options[:numLHS])
verbose = options[:verbose]
skip_cleanup = options[:noCleanup]
randseed = Integer(options[:randseed])
noEP = options[:noEP]

# if we are choosing noEP we also want to skip cleanup even
# if it hasn't been selected
skip_cleanup = true if noEP

# get the current working directory as the path
path = Dir.pwd

# expand filenames to full paths
osm_file = File.absolute_path(osm_name)
epw_file = File.absolute_path(epw_name)
outfile_path = File.absolute_path(outfile_name)
settings_file = File.absolute_path(settingsfile_name)

output_folder = "#{path}/PreRuns_Output"
models_folder = "#{path}/PreRuns_Models"
simulations_folder = "#{path}/PreRuns_Simulations"
# uqtable_folder = output_folder

# extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_name, '.osm')

Dir.mkdir(output_folder) unless Dir.exist?(output_folder)

if File.exist?(settings_file)
  puts "Using Output Settings = #{settings_file}" if verbose
  workbook = RubyXL::Parser.parse(settings_file.to_s)
  meters_table = []
  meters_table_row = []
  workbook['Meters'].each do |row|
    meters_table_row = []
    row.cells.each do |cell|
      meters_table_row.push(cell.value)
    end
    meters_table.push(meters_table_row)
  end
  if verbose
    puts 'Meters Table'
    puts meters_table
  end
else
  puts "#{settings_file}was NOT found!"
  abort
end

# check if .osm model exists and if so, load it
if File.exist?(osm_file.to_s)
  model = OpenStudio::Model::Model.load(osm_file).get
  puts "Using OSM file #{osm_file}" if verbose
else
  puts "OpenStudio file #{osm_file} not found!"
  abort
end

# check if .epw exists
if File.exist?(epw_file.to_s)
  puts "Using EPW file #{epw_file}" if verbose
else
  puts "Weather model #{epw_file} not found!"
  abort
end

# Generate LHS samples
lhs = LHSGenerator.new
input_path = path.to_s
preruns_path = "#{path}/PreRuns_Output"

puts 'Generating LHS samples' if verbose
lhs.lhs_samples_generator(input_path, priors_name, num_of_runs, output_folder, verbose, randseed)

samples = CSV.read("#{output_folder}/LHS_Samples.csv", headers: true)
parameter_names = []
parameter_types = []

samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end

uncertainty_parameters = UncertainParameters.new
priors_table = "#{path}/#{priors_name}"

if noEP
  if verbose
    puts
    puts '--noEP option selected, skipping generation of OpenStudio files and running of EnergyPlus'
    puts
  end
else  (2..samples[0].length - 1).each do |k|
        model = OpenStudio::Model::Model.load(osm_file).get # reload the model to get the same starting point each time
        parameter_value = []
        samples.each do |sample|
          parameter_value << sample[k].to_f
        end
        uncertainty_parameters.apply(model, parameter_types, parameter_names, parameter_value)

        # add selected reporting meters to the OSM file
        for meter_index in 1..(meters_table.length - 1)
          meter = OpenStudio::Model::Meter.new(model)
          meter.setName((meters_table[meter_index][0]).to_s)
          meter.setReportingFrequency((meters_table[meter_index][1]).to_s)
        end
        # add monthly ave air temp and solar radiation meters to OSM.  These are used as inputs to the calibration
        variable = OpenStudio::Model::OutputVariable.new('Site Outdoor Air Drybulb Temperature', model)
        variable.setReportingFrequency('Monthly')
        variable = OpenStudio::Model::OutputVariable.new('Site Ground Reflected Solar Radiation Rate per Area', model)
        variable.setReportingFrequency('Monthly')

        # meters saved to sql file
        model.save("#{models_folder}/Sample#{k - 1}.osm", true)

        # new edit start from here Yuna add for thermostat algorithm
        out_file_path_name_thermostat = "#{models_folder}/UQ_#{building_name}_thermostat.csv"
        model_output_path = "#{models_folder}/Sample#{k - 1}.osm"
        # uncertainty_parameters.thermostat_adjust(model, priors_table, out_file_path_name_thermostat, model_output_path, parameter_types, parameter_value)

        puts "Sample#{k - 1} is saved to the folder of Models" if verbose
      end

      runner = RunOSM.new
      runner.run_osm(models_folder, epw_file, simulations_folder, num_of_runs, verbose)

end # if noEP

# Read Simulation Results
OutPut.Read(simulations_folder, output_folder, settings_file, verbose)

# clean up the temp files if skip cleanup not set
unless skip_cleanup
  File.delete("#{output_folder}/LHS_Samples.csv") if File.exist?("#{output_folder}/LHS_Samples.csv")
  FileUtils.remove_dir(models_folder) if Dir.exist?(models_folder)
end
## Prepare calibration input files
# # y_sim, Monthly Drybuld, Monthly Solar Horizontal, Calibration parameter samples...

y_sim = []
if File.exist?("#{output_folder}/Meter_Electricity_Facility.csv")
  y_elec_table = CSV.read("#{output_folder}/Meter_Electricity_Facility.csv", headers: false)
  y_elec_table.delete_at(0) # delete the first row of the table because its a header
  # now we want to transpose and get rid of the first row and then flatten to concatenate all rows to one
  y_temp = y_elec_table.transpose
  y_temp.delete_at(0)
  y_sim << y_temp.flatten
end

if File.exist?("#{output_folder}/Meter_Gas_Facility.csv")
  # read in the gas table and process just as we did for electricity above
  y_gas_table = CSV.read("#{output_folder}/Meter_Gas_Facility.csv", headers: false)
  y_gas_table.delete_at(0) # delete the first element of this table
  y_temp = y_gas_table.transpose
  y_temp.delete_at(0)
  y_sim << y_temp.flatten

end

# now get this back to a 2 column array
y_sim = y_sim.transpose

weather_table = CSV.read("#{output_folder}/Monthly_Weather.csv", headers: false)
weather_table.delete_at(0)
weather_table = weather_table.transpose
monthly_temp = weather_table[0]
monthly_solar = weather_table[1]

# process the LHS parameter file
cal_parameter_samples_table = CSV.read("#{path}/PreRuns_Output/LHS_Samples.csv", headers: false)
cal_parameter_samples_table.delete_at(0)  # delete the main header
cal_parameter_samples_table = cal_parameter_samples_table.transpose
cal_parameter_samples_table.delete_at(0)  # delete the 1st row (was first column)
cal_parameter_samples_table.delete_at(0)  # delete the next row (was second column)

# replicate each row y_elec_table.length times to get a y_elec_table.lengthx num cal parameter samples array
# this version should work with daily or hourly
cal_parameter_samples = []
cal_parameter_samples_table.each do |run|
  for rep in 1..y_elec_table.length # Monthly
    cal_parameter_samples << run
  end
end

cal_data_com = []
y_sim.each_with_index do |y, index|
  cal_data_com << y + [monthly_temp[index]] + [monthly_solar[index]] + cal_parameter_samples[index]
end

writeToFile(cal_data_com, "#{output_folder}/cal_sim_runs.txt", verbose)
# FileUtils.cp "#{output_folder}/cal_sim_runs.txt", "#{path}/cal_sim_runs.txt"

utility_file = options[:utilityData]

# read in the utility meter data
y_meter = CSV.read("#{path}/#{utility_file}", headers: false)
y_meter.delete_at(0)
y_meter = y_meter.transpose
y_meter.delete_at(0)
y_meter = y_meter.transpose
puts "#{y_meter.length} months of data read from #{utility_file}" if verbose

# generate the cal_data_field as a table with columns of y_meter, monthly drybulb, monthly solar horizontal
cal_data_field = []
y_meter.each_with_index do |y, index|
  cal_data_field << y + [monthly_temp[index]] + [monthly_solar[index]]
end

writeToFile(cal_data_field, "#{output_folder}/cal_utility_data.txt")
# FileUtils.cp "#{output_folder}/cal_utility_data.txt", "#{path}/cal_utility_data.txt"

puts 'BC_Setup.rb Completed Successfully!' if verbose
