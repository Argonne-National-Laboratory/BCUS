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

# 1. Introduction
# This is the main function of analysis.

# 2. Call structure

# Use require to include functions from Ruby Library
require 'fileutils'
require 'csv'
require 'optparse'
require 'rubyXL'
require 'openstudio'

# Use require_relative to include ruby functions developed in the project
require_relative 'bcus_utils'
require_relative 'uncertain_parameters'
require_relative 'LHD'
require_relative 'Morris'
require_relative 'run_osm'
require_relative 'process_simulation_sqls'

# Parse command line inputs from the user
options = {:osmName => nil, :epwName => nil, :runType => nil}
parser = OptionParser.new do |opts|
  opts.banner = 'Usage: run_analysis.rb [options]'

  # osmName: OpenStudio Model Name in .osm
  opts.on('-o', '--osmName', 'osmName') do |osm_name|
    options[:osmName] = osm_name
  end

  # epwName: weather file used to run simulation in .epw
  opts.on('-e', '--epw epwName', 'epwName') do |epw_name|
    options[:epwName] = epw_name
  end

  # runType: Type of analysis
  opts.on('--runType runType', 'Type of analysis') do |run_type|
    options[:runType] = run_type
  end

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on(
    '--outFile outFile',
    'Simulation output setting file, default "Simulation_Output_Settings.xlsx"'
  ) do |out_file|
    options[:outFile] = out_file
  end

  options[:numLHD] = 500
  opts.on(
    '--numLHD numLHD',
    'Number of sample points of Monte Carlo simulation ' \
    'with Latin Hypercube Design sampling, default 500'
  ) do |num_lhd|
    options[:numLHD] = num_lhd
  end

  options[:morrisR] = 5
  opts.on(
    '--morrisR morrisR', 'Number of repetitions for morris method, default 5'
  ) do |morris_r|
    options[:morrisR] = morris_r
  end

  options[:morrisL] = 20
  opts.on(
    '--morrisL morrisL',
    'Number of levels for each parameter for morris method, default 20'
  ) do |morris_l|
    options[:morrisL] = morris_l
  end

  options[:uqRepo] = 'Parameter_UQ_Repository_V1.0.xlsx'
  opts.on(
    '-u', '--uqRepo uqRepo',
    'UQ repository file, default "Parameter_UQ_Repositorty_V1.0.xlsx"'
  ) do |uq_repo|
    options[:uqRepo] = uq_repo
  end

  options[:priorsFile] = 'Parameter_Priors.csv'
  opts.on(
    '--priors priorsFile',
    'Prior uncertainty information file, default "Parameter_Priors.csv"'
  ) do |priors_file|
    options[:priorsFile] = priors_file
  end

  options[:utilityData] = 'Utility_Data.csv'
  opts.on(
    '--utilityData utilityData',
    'Utility data file, default "Utility_Data.csv"'
  ) do |utility_data|
    options[:utilityData] = utility_data
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

  options[:interactive] = false
  opts.on(
    '-i', '--interactive', 'Run with interactive prompts to check setup files.'
  ) do
    options[:interactive] = true
  end

  options[:noEP] = false
  opts.on('--noEP', 'Do not run EnergyPlus') do
    options[:noEP] = true
  end

  options[:noCleanup] = false
  opts.on('-n', '--noCleanup', 'Do not clean up intermediate files.') do
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
error_msg = 'An OpenStudio OSM file must be indicated by the --osm option ' \
  'or giving a filename ending with .osm on the command line'
osm_path = File.absolute_path(parse_argv(options[:osmName], '.osm', error_msg))

# If the user didn't give the --epwName option, parse the rest of the input
# arguments for a *.epw
error_msg = 'An .epw weather file must be indicated by the --epw option ' \
  'or giving a filename ending with .epw on the command line'
epw_path = File.absolute_path(parse_argv(options[:epwName], '.epw', error_msg))

# Assign analysis settings
run_type = options[:runType]
outspec_path = File.absolute_path(options[:outFile])

num_processes = Integer(options[:numProcesses])
randseed = Integer(options[:randseed])
run_interactive = options[:interactive]
no_ep = options[:noEP]
skip_cleanup = options[:noCleanup]
verbose = options[:verbose]

# If we are choosing noEP we also want to skip cleanup even if
# it hasn't been selected
skip_cleanup = true if no_ep

case run_type
when 'UA'
  uqrepo_path = File.absolute_path(options[:uqRepo])
  num_lhd_runs = Integer(options[:numLHD])
  if verbose
    puts 'Running uncertainty analysis'
    puts "Using number of LHD samples  = #{num_lhd_runs}"
  end
when 'SA'
  uqrepo_path = File.absolute_path(options[:uqRepo])
  morris_reps = Integer(options[:morrisR])
  morris_levels = Integer(options[:morrisL])
  if verbose
    puts 'Running sensitivity analysis'
    puts "Using morris repetitions = #{morris_reps}"
    puts "Using morris levels = #{morris_levels}"
  end
when 'PreRuns'
  prior_path = File.absolute_path(options[:priorsFile])
  utility_path = File.absolute_path(options[:utilityData])
  num_lhd_runs = Integer(options[:numLHD])
  if verbose
    puts 'Preparing sample of computer models for Bayesian calibration'
    puts "Using number of LHD samples  = #{num_lhd_runs}"
  end
else
  puts 'Unrecognized analysis type'
  abort
end

if verbose
  puts "Using number of parallel processes  = #{num_processes}"
  puts "Using random seed = #{randseed}"
  puts 'Not cleaning up interim files' if skip_cleanup
end

wait_for_y('Running Interactively') if run_interactive

# Extract out just the base filename from the OSM file as the building name
building_name = File.basename(osm_path, '.osm')

# Check if .osm model exists and if so, load it
model = read_osm_file(osm_path, verbose)

# Check if or .epw file exists and if so, load it
check_epw_file(epw_path, verbose)

# Check if output file exist and if so, load it
meters_table = read_meters_table(outspec_path, verbose)

## Main process
# Acquire the path of the working directory that is the user's project folder
path = Dir.pwd
model_dir = File.join(path, "#{run_type}_Model")
sim_dir = File.join(path, "#{run_type}_Simulations")
output_dir = File.join(path, "#{run_type}_Output")
Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

# Step 1: Generate uncertainty distributions
puts "\nStep 1: Generating distribution of uncertainty parameters" if verbose
uncertainty_parameters = UncertainParameters.new
if run_type != 'PreRuns'
  # Load UQ repository file
  uq_path = File.join(output_dir, "UQ_#{building_name}.csv")
  uq_table = read_uq_table(uqrepo_path, verbose)
  # Remove the header rows
  2.times { uq_table.delete_at(0) }
  # Identify uncertainty parameters in the model
  uncertainty_parameters.find(model, uq_table, uq_path, verbose)
  # Check uncertainty information
  wait_for_y("Check the #{uq_path}") if run_interactive

else
  # Load prior distribution file
  uq_table = read_prior_table(prior_path, verbose)

end

# Step 2: Generate design matrix for analysis
puts "\nStep 2: Generating design Matrix and sample for analysis" if verbose
case run_type
when 'UA'
  # Generate LHD sample
  lhd = LHD.new
  lhd.lhd_samples_generator(
    uq_path, num_lhd_runs, output_dir, randseed, verbose
  )
  sample_filename = 'LHD_Sample.csv'
when 'SA'
  # Generate Morris design sample
  mor = Morris.new
  mor.morris_samples_generator(
    uq_path, morris_reps, morris_levels, output_dir, randseed, verbose
  )
  sample_filename = 'Morris_CDF_Tran_Design.csv'
when 'PreRuns'
  # Generate LHD sample
  lhd = LHD.new
  lhd.lhd_samples_generator(
    prior_path, num_lhd_runs, output_dir, randseed, verbose
  )
  sample_filename = 'LHD_Sample.csv'
end

# Generate sample of parameters
samples = CSV.read(File.join(output_dir, sample_filename), headers: false)
samples.delete_at(0)
num_of_runs = samples[0].length - 2

param_names, param_types, param_values = get_param_names_types_values(samples)

if no_ep
  if verbose
    puts
    puts '--noEP option selected, skipping creation of OpenStudio files ' \
      'and running of EnergyPlus'
    puts
  end
else
  puts "Going to run #{num_of_runs} models. This could take a while" if verbose

  # Generate sample of OSMs
  (0..(param_values.length - 1)).each do |k|
    # Reload the model explicitly to get the same starting point each time
    model = OpenStudio::Model::Model.load(osm_path).get
    uncertainty_parameters.apply(
      model, param_types, param_names, param_values[k]
    )

    # Add reporting meters
    add_reporting_meters_to_model(model, meters_table)

    # Add weather variable reporting to model and set its frequency
    add_output_variable_to_model(
      model, 'Site Outdoor Air Drybulb Temperature', 'Monthly'
    )
    add_output_variable_to_model(
      model, 'Site Ground Reflected Solar Radiation Rate per Area', 'Monthly'
    )

    # Model saved to osm file
    model.save(File.join(model_dir, "Sample#{k + 1}.osm"), true)

    # Add for thermostat algorithm
    uq_path_thermostat = File.join(
      output_dir, "UQ_#{building_name}_thermostat.csv"
    )
    model_output_path = File.join(model_dir, "Sample#{k + 1}.osm")
    uncertainty_parameters.thermostat_adjust(
      model, uq_table, uq_path_thermostat, model_output_path,
      param_types, param_values
    )

    puts "Sample#{k + 1} is saved to the folder of Models" if verbose
  end

  # Step 3: Run all OSM simulation files
  puts "\nStep 3: Running #{num_of_runs} OSM simulations" if verbose
  wait_for_y if run_interactive

  runner = RunOSM.new
  runner.run_osm(model_dir, epw_path, sim_dir, num_of_runs, num_processes)
end

# Step 4: Read Simulation Results
puts "\nStep 4: Post-processing and analyzing simulation results" if verbose
OutPut.read(sim_dir, outspec_path, output_dir, run_type == 'PreRuns', verbose)

# SA post-process
if run_type == 'SA'
  max_chars = 60
  mor.compute_sensitivities(
    File.join(output_dir, 'Simulation_Results_Building_Total_Energy.csv'),
    uq_path, output_dir, max_chars, verbose
  )
end

# Delete intermediate files
unless skip_cleanup
  FileUtils.remove_dir(model_dir) if Dir.exist?(model_dir)
  to_be_cleaned =
    case run_type
    when 'UA', 'PreRuns'
      ['Random_LHD_Samples.csv']
    when 'SA'
      [
        'Meter_Electricity_Facility.csv',
        'Meter_Gas_Facility.csv',
        'Morris_0_1_Design.csv',
        'Morris_CDF_Tran_Design.csv',
        'Simulation_Results_Building_Total_Energy.csv'
      ]
    end
  to_be_cleaned.each do |file|
    clean_path = File.join(output_dir, file)
    File.delete(clean_path) if File.exist?(clean_path)
  end
end

## Prepare calibration input files
# y_sim, monthly drybuld and solar horizontal, calibration parameter samples....

if run_type == 'PreRuns'

  y_elec_path = File.join(output_dir, 'Meter_Electricity_Facility.csv')
  y_gas_path = File.join(output_dir, 'Meter_Gas_Facility.csv')
  cal_sim_path = File.join(output_dir, 'cal_sim_runs.txt')
  cal_field_path = File.join(output_dir, 'cal_utility_data.txt')
  monthly_weather_path = File.join(output_dir, 'Monthly_Weather.csv')

  monthly_temp, monthly_solar = read_monthly_weather_file(monthly_weather_path)

  y_sim = get_y_sim(y_elec_path, y_gas_path)
  y_length = get_table_length(y_elec_path)

  cal_data_com = get_cal_data_com(
    y_sim, y_length, samples, monthly_temp, monthly_solar
  )
  write_to_file(cal_data_com, cal_sim_path, verbose)

  cal_data_field = get_cal_data_field(
    utility_path, monthly_temp, monthly_solar, verbose
  )
  write_to_file(cal_data_field, cal_field_path, verbose)

end

puts "\n#{run_type} completed successfully!"
