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
#    author and organization's name.
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
#     Contract No. DE-AC02-06CH11357 with the Department of Energy."
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
# - Updates 27-mar-2017 by RTM to pass verbose to Uncertain_Parameters call
# - Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
# - Created on March 15 2015 by Yuming Sun from Argonne National Laboratory
# - 02-Apr-2017: RTM: Added noEP option
# 15-Apr-2017: Updated call to output.read to reflect input file/dir
# formats/names and cleaned up code

# 1. Introduction
# This is the main function of uncertainty analysis.

# 2. Call structure
# Refer to 'Function Call Structure_UA.pptx'

# use require_relative to include ruby functions developed in the project
# Run_All_OSMs.rb is developed by OpenStudio team at NREL

require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
require_relative 'LHS_Morris'
require_relative 'Process_Simulation_SQLs'
require_relative 'bcus_utils'

# use require to include functions from Ruby Library
require 'openstudio'
require 'csv'
require 'rubyXL'
require 'optparse'
require 'fileutils'

# rubocop:disable LineLength
# parse commandline inputs from the user
options = { osmName: nil, epwName: nil }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: UA.rb [options]'

  opts.on('-o', '--osm osmName', 'osmName') do |osm|
    options[:osmName] = osm
  end

  opts.on('-e', '--epw epwName', 'epwName') do |epw|
    options[:epwName] = epw
  end

  options[:interactive] = false
  opts.on('-i', '--interactive', 'run with interactive prompts to check setup files') do
    options[:interactive] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end

  options[:uqRepo] = 'Parameter_UQ_Repository_V1.0.xlsx'
  opts.on('-u', '--uqRepo uqRepo', 'UQ Repository file (default "Parameter_UQ_Repository_V1.0.xlsx")') do |uq_repo_file|
    options[:uqRepo] = uq_repo_file
  end

  options[:settingsFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-s', '--settingsfile outFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |settings_file|
    options[:settingsFile] = settings_file
  end

  # num_LHS: the number of sample points of Monte Carlo simulation with Latin
  # Hypercube Design. If not user specified, 500 will be used as the default.
  options[:numLHS] = 500
  opts.on('--numLHS numLHS', 'numLHS') do |num_lhs|
    options[:numLHS] = num_lhs
  end

  options[:randseed] = 0
  opts.on('--seed seednum', 'Integer random number seed, 0 = no seed, default = 0') do |seednum|
    options[:randseed] = seednum
  end

  options[:verbose] = false
  opts.on('-v', '--verbose', 'Run in verbose mode with more output info printed') do
    options[:verbose] = true
  end

  options[:noEP] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noEP] = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

parser.parse!

error_msg = 'An OpenStudio OSM file must be indicated by the --osm option or giving a filename ending with .osm on the command line'
osm_file = File.absolute_path(parse_argv(options[:osmName], '.osm', error_msg))

error_msg = 'An .epw weather file must be indicated by the --epw option or giving a filename ending with .epw on the command line'
epw_file = File.absolute_path(parse_argv(options[:epwName], '.epw', error_msg))
# rubocop:enable LineLength

settings_file = File.absolute_path(options[:settingsFile])
uq_repo_file = File.absolute_path(options[:uqRepo])

run_interactive = options[:interactive]
skip_cleanup = options[:noCleanup]

num_lhs_runs = Integer(options[:numLHS])
verbose = options[:verbose]

randseed = Integer(options[:randseed])
no_ep = options[:noEP]

# if we are choosing no_ep we also want to skip cleanup even if it hasn't been selected
skip_cleanup = true if no_ep
puts 'Not Cleaning Up Interim Files' if skip_cleanup && verbose

wait_for_y('Running Interactively') if run_interactive

# Acquire the path of the working directory that is the user's project folder.
path = Dir.pwd

# extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_file, '.osm')

# check if .osm model exists and if so, load it
model = read_osm_file(osm_file, verbose)
check_epw_file(epw_file, verbose)

# use file join rather than string concatentation to get file separator right
output_folder = File.join(path, 'UA_Output')
models_folder = File.join(path, 'UA_Models')
simulations_folder = File.join(path, 'UA_Simulations')

Dir.mkdir output_folder unless Dir.exist?(output_folder)
Dir.mkdir models_folder unless Dir.exist?(models_folder)
Dir.mkdir simulations_folder unless Dir.exist?(simulations_folder)

meters_table = read_meters_table(settings_file, verbose)

uq_table = read_uq_table(uq_repo_file, verbose)
# remove the first two header rows from the table
uq_table.delete_at(0)
uq_table.delete_at(0)

# Define the output path of building specific uncertainty table
uq_table_name = File.join(output_folder, 'UQ_' + building_name + '.csv')

uncertainty_parameters = UncertainParameters.new
uncertainty_parameters.find(model, uq_table, uq_table_name, verbose)

wait_for_y("Check the #{uq_table_name}") if run_interactive

if verbose
  puts "Using Number of LHS samples  = #{num_lhs_runs}"
  puts "Using Random Seed = #{randseed}"
end

# run LHS sample generator and put the LHS sample file in output_folder
lhs = LHSGenerator.new
lhs.lhs_samples_generator(uq_table_name, num_lhs_runs, output_folder, verbose, randseed)

samples = CSV.read(File.join(output_folder, 'LHS_Samples.csv'), headers: true)

param_names, param_types, param_values = get_param_names_types_values(samples)

if no_ep
  if verbose
    puts
    puts '--noEP option selected, skipping creation of OpenStudio files and running of EnergyPlus'
    puts
  end
else
  puts "Going to run #{num_lhs_runs} models. This could take a while" if verbose
  wait_for_y if run_interactive
  uncertainty_parameters = UncertainParameters.new

  (0..(param_values.length - 1)).each do |k|
    # reload the model explicitly to get the same starting point each time
    model = OpenStudio::Model::Model.load(osm_file).get

    uncertainty_parameters.apply(model, param_types, param_names, param_values[k])

    # add reporting meters to model
    add_reporting_meters_to_model(model, meters_table)

    # add weather variable reporting to model and set its frequency
    add_output_variable_to_model(model, 'Site Outdoor Air Drybulb Temperature', 'Monthly')
    add_output_variable_to_model(model, 'Site Ground Reflected Solar Radiation Rate per Area', 'Monthly')

    # meters saved to sql file
    model_output_file = File.join(models_folder, "Sample#{k + 1}.osm")
    model.save(model_output_file, true)

    # create thermostat output tables and apply uncertainty to thermostats
    thermostat_output_file = File.join(output_folder, "UQ_#{building_name}_thermostat.csv")
    uncertainty_parameters.thermostat_adjust(model, uq_table, thermostat_output_file,
                                             model_output_file, param_types, param_values[k])

    puts "Sample#{k + 1} is saved to the folder of Models" if verbose
  end

  # run all the OSM simulation files
  runner = RunOSM.new
  runner.run_osm(models_folder, epw_file, simulations_folder,
                 num_lhs_runs, verbose)
end

# Read Simulation Results
OutPut.Read("#{path}/UA_Simulations", "#{path}/UA_Output", settings_file, verbose)

# delete intermediate files
unless skip_cleanup
  file_list = ['Monthly_Weather.csv']

  delete_files(output_folder, file_list, verbose)
  delete_folder(models_folder, verbose)
end

puts 'UA.rb Completed Successfully!' if verbose
