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

# - Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
# - Sep 2015 Cleaned up and new parsing added by Ralph Muehleisen from Argonne
# - Created on Feb27 2015 by Yuming Sun from Argonne National Laboratory
# - 02-Apr-2017: RTM: Added noEP option

# 1. Introduction
# This is the main function of sensitivity analysis using Morris Method[1].

# 2. Call structure
# 2.1 Call: Uncertain_Parameters.rb; Run_All_OSMs.rb;
#           Read_Simulation_Results_SQL.rb; and Morris.rb
# 2.2 Called by: The main function to execute from command line.

# References:
# [1] M. D. Morris, 1991, Factorial sampling plans for preliminary
#     computational experiments, Technometrics, 33, 161 - 174.

# use require_relative to include ruby functions developed in the project
# Run_All_OSMs.rb is developed by OpenStudio team at NREL
require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
require_relative 'Process_Simulation_SQLs'
require_relative 'LHS_Morris'
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
  opts.banner = 'Usage: SA.rb [options]'

  opts.on('--osm osmName', 'Name of .osm file to run') do |osm|
    options[:osmName] = osm
  end

  opts.on('--epw epwName', 'Name of .epw weather file to use') do |epw|
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
  opts.on('-u', '--uqRepo uqRepo', 'UQ Repository file (default "Parameter_UQ__Repository_V1.0.xlsx")') do |uq_repo_file|
    options[:uqRepo] = uq_repo_file
  end

  options[:settingsFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-s', '--settingsFile settingsFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |settings_file|
    options[:settingsFile] = settings_file
  end

  options[:morrisR] = 5
  opts.on('--morrisR morrisR', 'Number of paths, R, for morris method. Default = 5') do |morris_r|
    options[:morrisR] = morris_r
  end

  options[:morrisL] = 20
  opts.on('--morrisL morrisL', 'Number of levels for morris method. Default = 20') do |morris_l|
    options[:morrisL] = morris_l
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

error_msg = 'An OpenStudio OSM file must be indicated by the --osm option or giving a filename ending with .osm on the command line'
osm_file = File.absolute_path(parse_argv(options[:osmName], '.osm', error_msg))

error_msg = 'An .epw weather file must be indicated by the --epw option or giving a filename ending with .epw on the command line'
epw_file = File.absolute_path(parse_argv(options[:epwName], '.epw', error_msg))
# rubocop:enable LineLength

settings_file = File.absolute_path(options[:settingsFile])
uq_repo_file = File.absolute_path(options[:uqRepo])

verbose = options[:verbose]

run_interactive = options[:interactive]
skip_cleanup = options[:noCleanup]
morris_r = Integer(options[:morrisR])
morris_levels = Integer(options[:morrisL])
randseed = Integer(options[:randseed])
no_ep = options[:noEP]

# if we are choosing noEP we also want to skip cleanup even if it hasn't been selected
skip_cleanup = true if no_ep
puts 'Not Cleaning Up Interim Files' if skip_cleanup && verbose

wait_for_y('Running Interactively') if run_interactive

# set the user output base path to be the current working directory
path = Dir.pwd

output_folder = File.join(path, 'SA_Output')
models_folder = File.join(path, 'SA_Models')
simulations_folder = File.join(path, 'SA_Simulations')

Dir.mkdir output_folder unless Dir.exist?(output_folder)
Dir.mkdir models_folder unless Dir.exist?(models_folder)
Dir.mkdir simulations_folder unless Dir.exist?(simulations_folder)

# extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_file, '.osm')

model = read_osm_file(osm_file, verbose)
check_epw_file(epw_file, verbose)

uq_table = read_uq_table(uq_repo_file, verbose)
# remove the first two header rows from the table
uq_table.delete_at(0)
uq_table.delete_at(0)

meters_table = read_meters_table(settings_file, verbose)

if verbose
  puts "Using morris R = #{morris_r}"
  puts "Using morris levels = #{morris_levels}"
  puts "Random Number Seed = #{randseed}" if randseed != 0
end

uncertainty_parameters = UncertainParameters.new

puts 'Step 1: Generate uncertainty parameters distributions' if verbose
uq_table_name = File.join(output_folder, 'UQ_' + building_name + '.csv')

uncertainty_parameters.find(model, uq_table, uq_table_name, verbose)

puts 'Step2: Generate Morris Design Matrix' if verbose
morris = Morris.new
morris.design_matrix(output_folder, uq_table_name, morris_r, morris_levels, randseed, verbose)

# step 3, run the simulations.  Get number runs from the size of Morris_CDF_Tran_Design

samples = CSV.read("#{output_folder}/Morris_CDF_Tran_Design.csv", headers: true)

param_names, param_types, param_values = get_param_names_types_values(samples)

num_of_runs = param_values.length

if no_ep
  if verbose
    puts
    puts '--noEP option selected, skipping running of EnergyPlus'
    puts
  end
else
  puts "Step 3: Run #{num_of_runs} OSM Simulation may take a long time." if verbose
  wait_for_y if run_interactive

  (0..(param_values.length - 1)).each do |k|
    # reload the base model explicitly to get the same starting point each time
    model = OpenStudio::Model::Model.load(osm_file).get

    # apply uncertainty parameters to model
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

  # use the run manager to run through all the files put in SA_Models,
  # saving stuff in SA_Simulations
  runner = RunOSM.new
  runner.run_osm(models_folder, epw_file, simulations_folder, num_of_runs, verbose)

end

if verbose
  puts 'Step 4: Read simulation results, run Morris method analysis '\
  'and plot sensitivity results'
end

OutPut.Read(simulations_folder, output_folder, settings_file, verbose)

results_file = File.join(output_folder, 'Simulation_Results_Building_Total_Energy.csv')
# set the maximum size of variable names for printout in sensitivity analysis
max_chars = 60
morris.compute_sensitivities(results_file, output_folder, uq_table_name, verbose, max_chars)

unless skip_cleanup # delete intermediate files unless skip_cleanup chosen
  file_list = ['Morris_CDF_Tran_Design.csv',
               'Morris_0_1_Design.csv',
               'Monthly_Weather.csv',
               'Simulation_Results_Building_Total_Energy.csv']

  delete_files(output_folder, file_list, verbose)
  delete_folder(models_folder, verbose)

end

# puts meter_table.inspect

# meters_table.each_with_index do |row, index|
#   puts row[0].to_s

#

puts 'SA.rb Completed Successfully!' if verbose
