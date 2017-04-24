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
# - August 2016 by Yuna Zhang
# - Created on February 15 2015 by Yuming Sun from Argonne National Laboratory
#
# 08-Apr-2017 Ralph Muehleisen updated require_relative from LSH_Gen to
# LHS_Morris
# 08-Apr-2017 Ralph Muehleisen add --noEP option to parser to avoid running
# EnergyPlus if the prerun files exist
# 15-Apr-2017 Ralph Muehleisen converted code to read new columnar output of
# simulation meter files
# 21-Apr-2017 RTM ran rubocop linter for code cleanup

# 1. Introduction
# This is the main code used for setting up files for running Bayesian
# calibration.

#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for setting up files for running Bayesian calibration

require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
require_relative 'LHS_Morris'
require_relative 'Process_Simulation_SQLs'
require_relative 'rinruby'
require_relative 'bcus_utils'

require 'openstudio'
require 'optparse'
require 'fileutils'
require 'csv'
require 'rubyXL'

def get_y_sim(elec_file, gas_file)
  y_sim = []
  y_sim = add_to_table(y_sim, elec_file)
  y_sim = add_to_table(y_sim, gas_file)
  y_sim = y_sim.transpose
end



def get_cal_data_com(y_sim, y_length, lhs_table, temp, solar)
  cal_parameter_samples_table = lhs_table.transpose
  cal_parameter_samples_table.delete_at(0)  # delete the 1st row (was first column)
  cal_parameter_samples_table.delete_at(0)  # delete the next row (was second column)

  cal_parameter_samples = []
  cal_parameter_samples_table.each do |run|
    (1..y_length).each { cal_parameter_samples << run }
  end

  cal_data_com = []
  y_sim.each_with_index do |y, index|
    cal_data_com << y + [temp[index]] + [solar[index]] + cal_parameter_samples[index]
  end
  cal_data_com
end

def get_cal_data_field(utility_file, monthly_temp, monthly_solar)
  # read in the utility meter data
  y_meter = CSV.read(utility_file, headers: false)
  y_meter.delete_at(0)
  y_meter = y_meter.transpose
  y_meter.delete_at(0)
  y_meter = y_meter.transpose
  # puts "#{y_meter.length} months of data read from #{utility_file}" if verbose

  # generate the cal_data_field as a table with y_meter, monthly drybulb, monthly solar horizontal
  cal_data_field = []
  y_meter.each_with_index do |y, index|
    cal_data_field << y + [monthly_temp[index]] + [monthly_solar[index]]
  end
  cal_data_field
end

# rubocop:disable LineLength
# parse commandline inputs from the user
options = { osmName: nil, epwName: nil }
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: PreRuns_Calibration.rb [options]'

  # osm_name: OpenStudio Model Name in .osm
  opts.on('-o', '--osm osmName', 'osmName') do |osmName|
    options[:osmName] = osmName
  end

  # epw_name: weather file used to run simulation in .epw
  opts.on('-e', '--epw epwName', 'epwName') do |epwName|
    options[:epwName] = epwName
  end

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

error_msg = 'An OpenStudio OSM file must be indicated by the --osm option or giving a filename ending with .osm on the command line'
osm_file = File.absolute_path(parse_argv(options[:osmName], '.osm', error_msg))

error_msg = 'An .epw weather file must be indicated by the --epw option or giving a filename ending with .epw on the command line'
epw_file = File.absolute_path(parse_argv(options[:epwName], '.epw', error_msg))
# rubocop:enable LineLength

settings_file = File.absolute_path(options[:settingsFile])
utility_file = File.absolute_path(options[:utilityData])

priors_name = options[:priorsFile]
num_lhs_runs = Integer(options[:numLHS])
verbose = options[:verbose]
skip_cleanup = options[:noCleanup]
randseed = Integer(options[:randseed])
no_ep = options[:noEP]

# if we are choosing no_ep we also want to skip cleanup even
# if it hasn't been selected
skip_cleanup = true if no_ep

puts 'Not Cleaning Up Interim Files' if skip_cleanup && verbose

# get the current working directory as the path
path = Dir.pwd

# use file join rather than string concatentation to get file separator right
output_folder = File.join(path, 'PreRuns_Output')
models_folder = File.join(path, 'PreRuns_Models')
simulations_folder = File.join(path, 'PreRuns_Simulations')

Dir.mkdir output_folder unless Dir.exist?(output_folder)
Dir.mkdir models_folder unless Dir.exist?(models_folder)
Dir.mkdir simulations_folder unless Dir.exist?(simulations_folder)

# extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_file, '.osm')

model = read_osm_file(osm_file.to_s, verbose)
check_epw_file(epw_file.to_s, verbose)
meters_table = read_meters_table(settings_file.to_s, verbose)

# Generate LHS samples
lhs = LHSGenerator.new
input_path = path.to_s
# preruns_path = "#{path}/PreRuns_Output"

priors_file = File.join(input_path, priors_name)
puts 'Generating LHS samples' if verbose

lhs.lhs_samples_generator(priors_file, num_lhs_runs, output_folder, verbose, randseed)

lhs_samples = CSV.read(File.join(output_folder, 'LHS_Samples.csv'), headers: false)
lhs_samples.delete_at(0) # remove the headers

param_names, param_types, param_values = get_param_names_types_values(lhs_samples)

uncertainty_parameters = UncertainParameters.new
# priors_table = "#{path}/#{priors_name}"

if no_ep
  if verbose
    puts
    puts '--noEP option selected, skipping creation of OpenStudio files and running of EnergyPlus'
    puts
  end
else
  puts "Going to run #{num_lhs_runs} models. This could take a while" if verbose

  (0..(param_values.length - 1)).each do |k|
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

    # cannot calibrate thermostats yet so keep thise code commented out.
    # need to generate priors_table in the proper format for the thermostat algorithm
    # before this can be used.  Originally the uncertainty routine would parse but not any more
    #
    # thermostat_output_file = File.join(models_folder, "UQ_#{building_name}_thermostat.csv")
    # uncertainty_parameters.thermostat_adjust(model, priors_table, thermostat_output_file,
    #                                          model_output_file, param_types, param_values[k])

    puts "Sample#{k + 1} is saved to the folder of Models" if verbose
  end

  runner = RunOSM.new
  runner.run_osm(models_folder, epw_file, simulations_folder, num_lhs_runs, verbose)

end # if no_ep

# Read Simulation Results
OutPut.Read(simulations_folder, output_folder, settings_file, verbose)

# clean up the temp files if skip cleanup not set
unless skip_cleanup
  File.delete("#{output_folder}/LHS_Samples.csv") if File.exist?("#{output_folder}/LHS_Samples.csv")
  FileUtils.remove_dir(models_folder) if Dir.exist?(models_folder)
end
## Prepare calibration input files
# # y_sim, Monthly Drybuld, Monthly Solar Horizontal, Calibration parameter samples...

elec_file = File.join(output_folder, 'Meter_Electricity_Facility.csv')
gas_file = File.join(output_folder, 'Meter_Gas_Facility.csv')
cal_sim_runs_file = File.join(output_folder, 'cal_sim_runs.txt')
cal_utility_data_file = File.join(output_folder, 'cal_utility_data.txt')
monthly_weather_file = File.join(output_folder, 'Monthly_Weather.csv')

monthly_temp, monthly_solar = read_monthly_weather_file(monthly_weather_file)

y_sim = get_y_sim(elec_file, gas_file)
y_length = get_table_length(elec_file)

cal_data_com = get_cal_data_com(y_sim, y_length, lhs_samples, monthly_temp, monthly_solar)
write_to_file(cal_data_com, cal_sim_runs_file, verbose)

cal_data_field = get_cal_data_field(utility_file, monthly_temp, monthly_solar)
write_to_file(cal_data_field, cal_utility_data_file, verbose)
# FileUtils.cp "#{output_folder}/cal_utility_data.txt", "#{path}/cal_utility_data.txt"

puts 'BC_Setup.rb Completed Successfully!' if verbose
