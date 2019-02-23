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
# - August 2016 by Yuna Zhang
# - Created on February 15 2015 by Yuming Sun from Argonne National Laboratory

# 1. Introduction
# This is the main code used for setting up files for running Bayesian
# calibration.

#===============================================================%
#     author: Yuming Sun and Matt Riddle                        %
#     date: Feb 27, 2015                                        %
#===============================================================%

# Main code used for setting up files for running Bayesian calibration

require 'openstudio'
require 'optparse'
require 'fileutils'
require 'csv'
require 'rubyXL'
require 'rinruby'

require_relative 'run_all_osms'
require_relative 'Uncertain_Parameters'
require_relative 'LHD_gen'
require_relative 'read_simulation_results_sql'

def write_to_file(results, filename, verbose = false)
  File.open(filename, 'w+') do |f|
    results.each do |results_row|
      results_row.each do |r|
        f.write(r)
        f.write("\t")
      end
      f.write("\n")
    end
  end
  puts "Run results have been written to #{filename}" if verbose
end

# parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: PreRuns_Calibration.rb [options]'

  opts.on('--osmName osmName', 'osmName') do |osm_name|
    options[:osmName] = osm_name
  end

  opts.on('--epwName epwName', 'epwName') do |epw_name|
    options[:epwName] = epw_name
  end

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on(
    '-o', '--outFile outFile',
    'Simulation output setting file, default "Simulation_Output_Settings.xlsx"'
  ) do |out_file|
    options[:outFile] = out_file
  end

  options[:priorsFile] = 'Parameter Priors.csv'
  opts.on(
    '--priors priorsFile',
    'Prior uncertainty information file, default "Parameter Priors.csv"'
  ) do |priors_file|
    options[:priorsFile] = priors_file
  end

  options[:utilityData] = 'Utility Data.csv'
  opts.on(
    '--utilityData utilityData',
    'Utility data file, default "Utility Data.csv"'
  ) do |utility_data|
    options[:utilityData] = utility_data
  end

  options[:numLHS] = 100
  opts.on('--numLHS numLHS', 'numLHS') do |num_lhs|
    options[:numLHS] = num_lhs
  end

  options[:numProcesses] = 0
  opts.on(
    '--numProcesses numProcesses',
    'Number of parallel processes for simulation, 0 = no parallel, default 0'
  ) do |n_processes|
    options[:numProcesses] = n_processes
  end

  options[:randseed] = 0
  opts.on(
    '--seed seednum',
    'Integer random number seed, 0 = no seed, default 0'
  ) do |seednum|
    options[:randseed] = seednum
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files') do
    options[:noCleanup] = true
  end

  options[:verbose] = false
  opts.on(
    '-v', '--verbose', 'Run in verbose mode with more output info printed'
  ) do
    options[:verbose] = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end

parser.parse!

# If the user didn't give the --osmName option, parse the rest of the input
# arguments for a *.osm
if options[:osmName].nil?
  if ARGV.grep(/.osm/).any?
    temp = ARGV.grep(/.osm/)
    osm_name = temp[0]
  else
    puts 'An OpenStudio OSM file must be indicated by the --osmNAME option' \
         'or giving a filename ending with .osm on the command line'
    abort
  end
else # Otherwise the --osmName option was used
  osm_name = options[:osmName]
end

# If the user didn't give the --epwName option, parse the rest of the input
# arguments for a *.epw
if options[:epwName].nil?
  if ARGV.grep(/.epw/).any?
    temp = ARGV.grep(/.epw/)
    epw_name = temp[0]
  else
    puts 'An .epw weather file must be indicated by the --epwNAME option' \
         'or giving a filename ending with .epw on the command line'
    abort
  end
else # Otherwise the --epwName option was used
  epw_name = options[:epwName]
end

outfile_name = options[:outFile]
priors_name = options[:priorsFile]
num_of_runs = Integer(options[:numLHS])
verbose = options[:verbose]
skip_cleanup = options[:noCleanup]
num_processes = Integer(options[:numProcesses])
randseed = Integer(options[:randseed])

# get the current working directory as the path
path = Dir.pwd

# expand filenames to full paths
osm_path = File.absolute_path(osm_name)
epw_path = File.absolute_path(epw_name)
outfile_path = File.absolute_path(outfile_name)

# Extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_name, '.osm')

Dir.mkdir "#{path}/PreRuns_Output" unless Dir.exist?("#{path}/PreRuns_Output")

if File.exist?(outfile_path)
  puts "Using Output Settings = #{outfile_path}" if verbose
  workbook = RubyXL::Parser.parse(outfile_path)
  meters_table = []
  meters_table_row = []
  workbook['Meters'].each do |row|
    meters_table_row = []
    row.cells.each { |cell| meters_table_row.push(cell.value) }
    meters_table.push(meters_table_row)
  end
else
  puts "#{outfile_path} was NOT found!"
  abort
end

# Check if .osm model exists and if so, load it
if File.exist?(osm_path)
  model = OpenStudio::Model::Model.load(osm_path).get
  puts "Using OSM file #{osm_path}" if verbose
else
  puts "OpenStudio file #{osm_path} not found!"
  abort
end

# Check if .epw exists and if so, load it
if File.exist?(epw_path)
  puts "Using EPW file #{epw_path}" if verbose
else
  puts "Weather model #{epw_path} not found!"
  abort
end

# Generate LHS samples
lhs = LHSGenerator.new
input_path = path.to_s
preruns_path = "#{path}/PreRuns_Output"

lhs.lhs_samples_generator(
  "#{input_path}/#{priors_name}", num_of_runs, preruns_path, randseed, verbose
)

samples = CSV.read("#{path}/PreRuns_Output/LHS_Samples.csv", headers: true)
parameter_names = []
parameter_types = []

samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end

uncertainty_parameters = UncertainParameters.new

priors_table = "#{path}/#{priors_name}"

(2..samples[0].length - 1).each do |k|
  model = OpenStudio::Model::Model.load(osm_path).get
  parameter_value = []
  samples.each { |sample| parameter_value << sample[k].to_f }
  uncertainty_parameters.apply(
    model, parameter_types, parameter_names, parameter_value
  )
  # Add reporting meters
  (1..(meters_table.length - 1)).each do |meter_index|
    meter = OpenStudio::Model::OutputMeter.new(model)
    meter.setName(meters_table[meter_index][0].to_s)
    meter.setReportingFrequency(meters_table[meter_index][1].to_s)
  end
  variable = OpenStudio::Model::OutputVariable.new(
    'Site Outdoor Air Drybulb Temperature', model
  )
  variable.setReportingFrequency('Monthly')
  variable = OpenStudio::Model::OutputVariable.new(
    'Site Ground Reflected Solar Radiation Rate per Area', model
  )
  variable.setReportingFrequency('Monthly')

  # Meters saved to sql file
  model.save("#{path}/PreRuns_Models/Sample#{k - 1}.osm", true)

  # new edit start from here Yuna add for thermostat algorithm
  # out_file_path_name_thermostat =
  #   "#{path}/PreRuns_Models/UQ_#{building_name}_thermostat.csv"
  # model_output_path = "#{path}/PreRuns_Models/Sample#{k - 1}.osm"
  # uncertainty_parameters.thermostat_adjust(
  #   model, priors_table, out_file_path_name_thermostat, model_output_path,
  #   parameter_types, parameter_value
  # )

  puts "Sample#{k - 1} is saved to the folder of Models" if verbose
end

runner = RunOSM.new
runner.run_osm(
  "#{path}/PreRuns_Models",
  epw_path,
  "#{path}/PreRuns_Simulations",
  num_processes,
  verbose
)

# Read Simulation Results
project_path = path.to_s
OutPut.read(num_of_runs, project_path, 'PreRuns')

# clean up the temp files if skip cleanup not set
unless skip_cleanup
  if File.exist?("#{path}/PreRuns_Output/Random_LHS_Samples.csv")
    File.delete("#{path}/PreRuns_Output/Random_LHS_Samples.csv")
  end
  if Dir.exist?("#{path}/PreRuns_Models")
    FileUtils.remove_dir("#{path}/PreRuns_Models")
  end
end

## Prepare calibration input files
# y_sim, Monthly Drybuld, Monthly Solar Horizontal, Calibration parameter
# samples...
y_sim = []
if File.exist?("#{path}/PreRuns_Output/Meter_Electricity_Facility.csv")
  y_elec_table = CSV.read(
    "#{path}/PreRuns_Output/Meter_Electricity_Facility.csv", headers: false
  )
  y_elec_table.delete_at(0)
  y_elec_table.each do |run|
    run.each do |data|
      y_sim << data.to_f
    end
  end
end

if File.exist?("#{path}/PreRuns_Output/Meter_Gas_Facility.csv")
  y_gas_table = CSV.read(
    "#{path}/PreRuns_Output/Meter_Gas_Facility.csv", headers: false
  )
  y_gas_table.delete_at(0)
  row = 0
  y_gas_table.each do |run|
    run.each do |data|
      y_sim[row] = [y_sim[row], data.to_f]
      row += 1
    end
  end
end

weather_table = CSV.read(
  "#{path}/PreRuns_Output/Monthly_Weather.csv", headers: false
)
weather_table.delete_at(0)
weather_table = weather_table.transpose
monthly_temp = weather_table[0]
monthly_solar = weather_table[1]

cal_parameter_samples_table = CSV.read(
  "#{path}/PreRuns_Output/LHS_Samples.csv", headers: false
)
cal_parameter_samples_table.delete_at(0)
cal_parameter_samples_table = cal_parameter_samples_table.transpose
cal_parameter_samples_table.delete_at(0)
cal_parameter_samples_table.delete_at(0)

cal_parameter_samples = []
cal_parameter_samples_table.each do |run|
  (1..12).each { |_| cal_parameter_samples << run } # Monthly
end

cal_data_com = []
y_sim.each_with_index do |y, index|
  cal_data_com << y + [monthly_temp[index]] + [monthly_solar[index]] + cal_parameter_samples[index]
end

write_to_file(cal_data_com, "#{path}/PreRuns_Output/cal_sim_runs.txt", verbose)
FileUtils.cp(
  "#{path}/PreRuns_Output/cal_sim_runs.txt", "#{path}/cal_sim_runs.txt"
)

utility_file = options[:utilityData]

# read in the utility meter data
y_meter = CSV.read("#{path}/#{utility_file}", headers: false)
y_meter.delete_at(0)
y_meter = y_meter.transpose
y_meter.delete_at(0)
y_meter = y_meter.transpose
puts "#{y_meter.length} months of data read from #{utility_file}" if verbose

# generate the cal_data_field as a table with columns of y_meter, monthly
# drybulb, monthly solar horizontal
cal_data_field = []
y_meter.each_with_index do |y, index|
  cal_data_field << y + [monthly_temp[index]] + [monthly_solar[index]]
end

puts "cal_data_field length = #{cal_data_field.length}" if verbose
write_to_file(cal_data_field, "#{path}/PreRuns_Output/cal_utility_data.txt")
FileUtils.cp(
  "#{path}/PreRuns_Output/cal_utility_data.txt", "#{path}/cal_utility_data.txt"
)

puts 'BC_Setup.rb Completed Successfully!'
