# Copyright © 2016 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.  Software changes, modifications, or derivative works, should be noted with comments and the author and organization’s name.

# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

# 4. The software and the end-user documentation included with the redistribution, if any, must include the following acknowledgment:

#    "This product includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.”

# ******************************************************************************************************
# DISCLAIMER

# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

# ***************************************************************************************************

# Modified Date and By:

# - Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
# - Sep 2015 Cleaned up and new parsing added by Ralph Muehleisen from Argonne National Laboratory
# - Created on Feb27 2015 by Yuming Sun from Argonne National Laboratory
# - 02-Apr-2017: RTM: Added noEP option


# 1. Introduction
# This is the main function of sensitivity analysis using Morris Method[1].

# 2. Call structure
# 2.1 Call: Uncertain_Parameters.rb; Run_All_OSMs.rb; Read_Simulation_Results_SQL.rb; and Morris.rb
# 2.2 Called by: The main function to execute from command line.

# References:
# [1] M. D. Morris, 1991, Factorial sampling plans for preliminary computational experiments, Technometrics, 33, 161–174.

# use require_relative to include ruby functions developed in the project
# Run_All_OSMs.rb is developed by OpenStudio team at NREL
require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
require_relative 'Process_Simulation_SQLs'
require_relative 'LHS_Morris'

# use require to include functions from Ruby Library
require 'openstudio'
require 'csv'
require 'rubyXL'
require 'optparse'
require 'fileutils'

# define prompt to wait for user to enter y or Y to continue for interactive
def wait_for_y
  check = 'n'
  while check != 'y' && check != 'Y'
    puts "Please enter 'Y' or 'y' to continue, 'n' or 'N' or 'CTRL-Z' to quit"
    # read from keyboard, strip leading and trailing spaces and convert to lower case
    check = $stdin.gets.strip.downcase
    abort if check == 'n'
  end
end

# parse commandline inputs from the user
options = { osmName: nil, epwName: nil }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: SA.rb [options]'

  opts.on('--osmName osmName', 'Name of .osm file to run') do |osmName|
    options[:osmName] = osmName
  end

  opts.on('--epwName epwName', 'Name of .epw weather file to use') do |epwName|
    options[:epwName] = epwName
  end

  options[:interactive] = false
  opts.on('-i', '--interactive', 'run with interactive prompts to check setup files') do
    options[:interactive] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end

  options[:uqRepo] = 'Parameter UQ Repository V1.0.xlsx'
  opts.on('-u', '--uqRepo uqRepo', 'UQ Repository file (default "Parameter UQ Repositorty V1.0.xlsx")') do |uqRepo|
    options[:uqRepo] = uqRepo
  end

  options[:settingsFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-s', '--settingsFile settingsFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |settingsFile|
    options[:settingsFile] = settingsFile
  end

  options[:morrisR] = 5
  opts.on('--morrisR morrisR', 'Number of paths, R, for morris method.  Default = 5') do |morrisR|
    options[:morrisR] = morrisR
  end

  options[:morrisL] = 20
  opts.on('--morrisL morrisL', 'Number of levels for morris method.  Default = 20') do |morrisL|
    options[:morrisL] = morrisL
  end

  options[:randseed] = 0
  opts.on('--seed randseed', 'Integer random number seed, 0 = no seed, default = 0') do |randseed|
    options[:randseed] = randseed
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
    temp = ARGV.grep(/.osm/)
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
    temp = ARGV.grep(/.epw/)
    epw_name = temp[0]
  else
    puts 'An .epw weather file must be indicated by the --epwNAME option or giving a filename ending with .epw on the command line'
    abort
  end
else # otherwise the --epwName option was used
  epw_name = options[:epwName]
end

verbose = options[:verbose]
uqrepo_name = options[:uqRepo]
settingsfile_name = options[:settingsFile]
run_interactive = options[:interactive]
skip_cleanup = options[:noCleanup]
morris_R = Integer(options[:morrisR])
morris_levels = Integer(options[:morrisL])
randseed = Integer(options[:randseed])
noEP = options[:noEP]

# if we are choosing noEP we also want to skip cleanup even if it hasn't been selected
skip_cleanup = true if noEP

if run_interactive
  puts 'Running Interactively'
  wait_for_y
end

puts 'Not Cleaning Up Interim Files' if (skip_cleanup && verbose)

# set the user output base path to be the current working directory
path = Dir.pwd

# expand filenames to full paths
osm_path = File.absolute_path(osm_name)
epw_path = File.absolute_path(epw_name)
uqrepo_path = File.absolute_path(uqrepo_name)
settingsfile = File.absolute_path(settingsfile_name)

output_folder = "#{path}/SA_Output"
models_folder = "#{path}/SA_Models"
simulations_folder = "#{path}/SA_Simulations"
# extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_name, '.osm')

# check if .osm model exists and if so, load it
if File.exist?(osm_path.to_s)
  model = OpenStudio::Model::Model::load(osm_path).get
  puts "Using OSM file #{osm_path}" if verbose
else
  puts "OpenStudio file #{osm_path} not found!"
  abort
end

# check if .epw exists
if File.exist?(epw_path.to_s)
  puts "Using EPW file #{epw_path}" if verbose
else
  puts "Weather model #{epw_path} not found!"
  abort
end

if File.exist?(uqrepo_path.to_s)
  puts "Using UQ repository = #{uqrepo_path}" if verbose
  workbook = RubyXL::Parser.parse(uqrepo_path.to_s)
  uq_table = []
  uq_table_row = []
  workbook['UQ'].each do |row|
    uq_table_row = []
    row.cells.each do |cell|
      uq_table_row.push(cell.value)
    end
    uq_table.push(uq_table_row)
  end
else
  puts "#{uqrepo_path} was NOT found!"
  abort
end

# remove the first two rows of headers
uq_table.delete_at(0)
uq_table.delete_at(0)

if File.exist?(settingsfile.to_s)
  puts "Using Output Settings = #{settingsfile}" if verbose
  workbook = RubyXL::Parser.parse(settingsfile.to_s)
  meters_table = []
  meters_table_row = []
  workbook['Meters'].each do |row|
    meters_table_row = []
    row.cells.each do |cell|
      meters_table_row.push(cell.value)
    end
    meters_table.push(meters_table_row)
  end
else
  puts "#{settingsfile} was NOT found!"
  abort
end

if verbose
  puts "Using morris R = #{morris_R}"
  puts "Using morris levels = #{morris_levels}"
  puts "Random Number Seed = #{randseed}" if randseed != 0
end

uncertainty_parameters = UncertainParameters.new

Dir.mkdir output_folder unless Dir.exist?(output_folder)

puts 'Step 1: Generate uncertainty parameters distributions' if verbose
file_name = "#{output_folder}/UQ_#{building_name}.csv"
uncertainty_parameters.find(model, uq_table, file_name, verbose)

puts 'Step2: Generate Morris Design Matrix' if verbose
morris = Morris.new
morris.design_matrix(output_folder, file_name, morris_R, morris_levels, randseed, verbose)

# step 3, run the simulations.  Get number runs from the size of Morris_CDF_Tran_Design
samples = CSV.read("#{output_folder}/Morris_CDF_Tran_Design.csv", headers: true)

parameter_names = []
parameter_types = []
samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end
num_of_runs = samples[0].length - 2
puts "Step 3: Run #{num_of_runs} OSM simulations" if verbose

# wait_for_y if run_interactive
if run_interactive
  puts "Step 3: Run #{num_of_runs} OSM Simulation may take a long time."
  wait_for_y if run_interactive
end
if noEP
  if verbose
    puts
    puts '--noEP option selected, skipping running of EnergyPlus'
    puts
  end
else
  (2..(samples[0].length - 1)).each do |k|
    model = OpenStudio::Model::Model::load(osm_path).get # reload the model to get the same starting point each time
    parameter_value = []
    samples.each { |sample| parameter_value << sample[k].to_f }
    uncertainty_parameters.apply(model, parameter_types, parameter_names, parameter_value)
    # add reporting meters
    (1..(meters_table.length - 1)).each do |meter_index|
      meter = OpenStudio::Model::Meter.new(model)
      meter.setName(meters_table[meter_index][0].to_s)
      meter.setReportingFrequency(meters_table[meter_index][1].to_s)
    end
    variable = OpenStudio::Model::OutputVariable.new('Site Outdoor Air Drybulb Temperature', model)
    variable.setReportingFrequency('Monthly')
    variable = OpenStudio::Model::OutputVariable.new('Site Ground Reflected Solar Radiation Rate per Area', model)
    variable.setReportingFrequency('Monthly')

    # meters saved to sql file
    model.save("#{models_folder}/Sample#{k - 1}.osm", true)

    # new edit start from here Yuna add for thermostat algorithm
    out_file_path_name_thermostat = "#{output_folder}/UQ_#{building_name}_thermostat.csv"
    model_output_path = "#{models_folder}/Sample#{k - 1}.osm"
    uncertainty_parameters.thermostat_adjust(model, uq_table, out_file_path_name_thermostat, model_output_path, parameter_types, parameter_value)

    puts "Sample#{k - 1} is saved to the folder of Models" if verbose
  end

  # use the run manager to run through all the files put in SA_Models, saving stuff in SA_Simulations
  runner = RunOSM.new
  runner.run_osm(models_folder, epw_path, simulations_folder, num_of_runs, verbose)

end

puts 'Step 4: Read simulation results, run Morris method analysis and plot sensitivity results' if verbose
results_file = "#{output_folder}/Simulation_Results_Building_Total_Energy.csv"
OutPut.Read(simulations_folder, output_folder, settingsfile, verbose)
num_variable_name_chars = 60 # set the maximum size of variable names for printout in sensitivity analysis
morris.compute_sensitivities(results_file, output_folder, file_name, verbose, num_variable_name_chars)

unless skip_cleanup # delete intermediate files unless skip_cleanup was selected.

  File.delete("#{output_folder}/Morris_CDF_Tran_Design.csv") if File.exist?("#{path}/SA_Output/Morris_CDF_Tran_Design.csv")
  File.delete("#{output_folder}/Morris_0_1_Design.csv") if File.exist?("#{path}/SA_Output/Morris_0_1_Design.csv")
  File.delete("#{output_folder}/Monthly_Weather.csv") if File.exist?("#{path}/SA_Output/Monthly_Weather.csv")
  File.delete("#{output_folder}/Meter_Electricity.csv") if File.exist?("#{path}/SA_Output/Meter_Electricity_Facility.csv")
  File.delete("#{output_folder}/Meter_Gas.csv") if File.exist?("#{path}/SA_Output/Meter_Gas_Facility.csv")
  File.delete("#{output_folder}/Simulation_Results_Building_Total_Energy.csv") if File.exists?("#{output_folder}/Simulation_Results_Building_Total_Energy.csv")
  File.delete("#{path}/Morris_design") if File.exist?("#{path}/Morris_design")
  FileUtils.remove_dir(models_folder) if Dir.exist?(models_folder)
end

puts 'SA.rb Completed Successfully!' if verbose
