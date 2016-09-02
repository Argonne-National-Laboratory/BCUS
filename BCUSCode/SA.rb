=begin comments
Copyright © 2016 , UChicago Argonne, LLC
All Rights Reserved
OPEN SOURCE LICENSE

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.  Software changes, modifications, or derivative works, should be noted with comments and the author and organization’s name.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

4. The software and the end-user documentation included with the redistribution, if any, must include the following acknowledgment:

   "This product includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.”

******************************************************************************************************
DISCLAIMER

THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.

NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.

***************************************************************************************************

Modified Date and By:

- Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
- Sep 2015 Cleaned up and new parsing added by Ralph Muehleisen from Argonne National Laboratory
- Created on Feb27 2015 by Yuming Sun from Argonne National Laboratory


1. Introduction
This is the main function of sensitivity analysis using Morris Method[1].

2. Call structure
2.1 Call: Uncertain_Parameters.rb; Run_All_OSMs.rb; Read_Simulation_Results_SQL.rb; and Morris.rb
2.2 Called by: The main function to execute from command line.

References:
[1] M. D. Morris, 1991, Factorial sampling plans for preliminary computational experiments, Technometrics, 33, 161–174.

=end

# use require_relative to include ruby functions developed in the project
# Run_All_OSMs.rb is developed by OpenStudio team at NREL
require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
require_relative 'Read_Simulation_Results_SQL'
require_relative 'Morris'
# use require to include functions from Ruby Library
require 'openstudio'
require 'csv'
require 'rubyXL'
require 'optparse'
require 'fileutils'

# define prompt to wait for user to enter y or Y to continue for interactive 
def wait_for_y
  check = 'n'
  while check != 'y' and check != 'Y'
    puts "Please enter 'Y' or 'y' to continue, 'n' or 'N' or 'CTRL-Z' to quit"
    #check = Readline.readline().squeeze(" ").strip.downcase
    # read from keyboard, strip leading and trailing spaces and convert to lower case
    check = $stdin.gets.strip.downcase
    if check == 'n'
      abort
    end
  end
end


# parse commandline inputs from the user
options = {:osmName => nil, :epwName => nil}
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

  options[:outFile] = 'Simulation_Output_Settings.xlsx'
  opts.on('-o', '--outfile outFile', 'Simulation Output Setting File (default "Simulation_Output_Settings.xlsx")') do |outFile|
    options[:outFile] = outFile
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
  opts.on('--seed seednum', 'Integer random number seed, 0 = no seed, default = 0') do |seednum|
    options[:randseed] = seednum
  end

  options[:verbose] = false
  opts.on('-v', '--verbose', 'Run in verbose mode with more output info printed') do
    options[:verbose] = true
  end

  opts.on('-h', '--help', 'Displays Help') do
    puts opts
    exit
  end
end
parser.parse!

# if the user didn't give the --osmName option, parse the rest of the input arguments for a *.osm
if options[:osmName] == nil
  if ARGV.grep(/.osm/).any?
    temp=ARGV.grep /.osm/
    osm_name=temp[0]
  else
    puts 'An OpenStudio OSM file must be indicated by the --osmNAME option or giving a filename ending with .osm on the command line'
    abort
  end
else # otherwise the --osmName option was used
  osm_name = options[:osmName]
end

# if the user didn't give the --epwName option, parse the rest of the input arguments for a *.epw
if options[:epwName] == nil
  if ARGV.grep(/.epw/).any?
    temp=ARGV.grep /.epw/
    epw_name=temp[0]
  else
    puts 'An .epw weather file must be indicated by the --epwNAME option or giving a filename ending with .epw on the command line'
    abort
  end
else # otherwise the --epwName option was used
  epw_name = options[:epwName]
end

verbose = options[:verbose]
uqrepo_name = options[:uqRepo]
outfile_name = options[:outFile]
run_interactive = options[:interactive]
skip_cleanup = options[:noCleanup]
morris_R = Integer(options[:morrisR])
morris_levels = Integer(options[:morrisL])
randseed = Integer(options[:randseed])

if run_interactive
  puts 'Running Interactively'
  wait_for_y
end

puts 'Not Cleaning Up Interim Files' if skip_cleanup

# set the user output base path to be the current working directory 
path = Dir.pwd

# expand filenames to full paths
osm_path = File.absolute_path(osm_name)
epw_path = File.absolute_path(epw_name)
uqrepo_path = File.absolute_path(uqrepo_name)
outfile_path = File.absolute_path(outfile_name)

#extract out just the base filename from the OSM file as the building name
building_name=File.basename(osm_name, '.osm')

# check if .osm model exists and if so, load it
if File.exist?("#{osm_path}")
  model = OpenStudio::Model::Model::load(osm_path).get
  puts "Using OSM file #{osm_path}" if verbose
else
  puts "OpenStudio file #{osm_path} not found!"
  abort
end

# check if .epw exists
if File.exist?("#{epw_path}")
  puts "Using EPW file #{epw_path}" if verbose
else
  puts "Weather model #{epw_path} not found!"
  abort
end

if File.exist?("#{uqrepo_path}")
  puts "Using UQ repository = #{uqrepo_path}" if verbose
  workbook = RubyXL::Parser.parse("#{uqrepo_path}")
  # uq_table = workbook['UQ'].extract_data  outdated by June 28th
  uq_table = Array.new
  uq_table_row = Array.new
  workbook['UQ'].each { |row|
    uq_table_row = []
    row.cells.each { |cell|
      uq_table_row.push(cell.value)
    }
    uq_table.push(uq_table_row)
  }
else
  puts "#{uqrepo_path} was NOT found!"
  abort
end

if File.exist?("#{outfile_path}")
  puts "Using Output Settings = #{outfile_path}" if verbose
  workbook = RubyXL::Parser.parse("#{outfile_path}")
  meters_table = Array.new
  meters_table_row = Array.new
  workbook['Meters'].each { |row|
    meters_table_row = []
    row.cells.each { |cell|
      meters_table_row.push(cell.value)
    }
    meters_table.push(meters_table_row)
  }

else
  puts "#{outfile_path}was NOT found!"
  abort
end

if verbose
  puts "Using morris R = #{morris_R}"
  puts "Using morris levels = #{morris_levels}"
  puts "Random Number Seed = #{randseed}" if randseed != 0
end


# remove the first two rows of headers
(1..2).each { |i|
  uq_table.delete_at(0)
  i += 1
}

uncertainty_parameters = UncertainParameters.new

Dir.mkdir "#{path}/SA_Output" unless Dir.exist?("#{path}/SA_Output")

if verbose
  puts 'Step 1: Generate uncertainty parameters distributions'
end

file_name = "#{path}/SA_Output/UQ_#{building_name}.csv"
uncertainty_parameters.find(model, uq_table, file_name, verbose)

morris = Morris.new
file_path = "#{path}/SA_Output"
morris.design_matrix(file_path, file_name, morris_R, morris_levels, randseed)

# Step 3: Run Simulations
samples = CSV.read("#{path}/SA_Output/Morris_CDF_Tran_Design.csv", headers: true)
parameter_names = []
parameter_types = []
samples.each do |sample|
  parameter_names << sample[1]
  parameter_types << sample[0]
end
num_of_runs = samples[0].length-2

if verbose
  puts 'Step 2: Design Matrix for Morris SA was generated.'
  puts "Step 3: Run #{num_of_runs} OSM simulations"
end

#wait_for_y if run_interactive
if run_interactive
  puts "Step 3: Run #{num_of_runs} OSM Simulation may take a long time."
  wait_for_y if run_interactive
end

for k in 2..samples[0].length-1
  model = OpenStudio::Model::Model::load(osm_path).get
  parameter_value = []
  samples.each { |sample| parameter_value << sample[k].to_f }
  uncertainty_parameters.apply(model, parameter_types, parameter_names, parameter_value)
  # add reporting meters
  for meter_index in 1..(meters_table.length-1)
    meter = OpenStudio::Model::Meter.new(model)
    meter.setName("#{meters_table[meter_index][0]}")
    meter.setReportingFrequency("#{meters_table[meter_index][1]}")
  end
  variable = OpenStudio::Model::OutputVariable.new('Site Outdoor Air Drybulb Temperature', model)
  variable.setReportingFrequency('Monthly')
  variable = OpenStudio::Model::OutputVariable.new('Site Ground Reflected Solar Radiation Rate per Area', model)
  variable.setReportingFrequency('Monthly')

  # meters saved to sql file
  model.save("#{path}/SA_Models/Sample#{k-1}.osm", true)

  # new edit start from here Yuna add for thermostat algorithm
  out_file_path_name_thermostat = "#{path}/SA_Output/UQ_#{building_name}_thermostat.csv"
  model_output_path = "#{path}/SA_Models/Sample#{k-1}.osm"
  uncertainty_parameters.thermostat_adjust(model, uq_table, out_file_path_name_thermostat, model_output_path, parameter_types, parameter_value)

  puts "Sample#{k-1} is saved to the folder of Models" if verbose
end

# use the run manager to run through all the files put in SA_Models, saving stuff in SA_Simulations
runner = RunOSM.new()
runner.run_osm("#{path}/SA_Models",
               epw_path,
               "#{path}/SA_Simulations",
               num_of_runs,
               verbose)

# Step 4: Read Simulation Results
# Run morris method to compute and plot sensitivity results
project_path = "#{path}"
OutPut.Read(num_of_runs, project_path, 'SA')
morris.compute_sensitivities("#{path}/SA_Output/Simulation_Results_Building_Total_Energy.csv", file_path, file_name)

unless skip_cleanup
  #delete intermediate files

  File.delete("#{path}/SA_Output/Morris_CDF_Tran_Design.csv") if File.exists?("#{path}/SA_Output/Morris_CDF_Tran_Design.csv")
  File.delete("#{path}/SA_Output/Morris_0_1_Design.csv") if File.exists?("#{path}/SA_Output/Morris_0_1_Design.csv")
  File.delete("#{path}/SA_Output/Monthly_Weather.csv") if File.exists?("#{path}/SA_Output/Monthly_Weather.csv")
  File.delete("#{path}/SA_Output/Monthly_Weather.csv") if File.exists?("#{path}/SA_Output/Monthly_Weather.csv")
  File.delete("#{path}/SA_Output/Meter_Electricity.csv") if File.exists?("#{path}/SA_Output/Meter_Electricity.csv")
  File.delete("#{path}/SA_Output/Meter_Gas.csv") if File.exists?("#{path}/SA_Output/Meter_Gas.csv")
  File.delete("#{path}/SA_Output/Simulation_Results_Building_Total_Energy.csv") if File.exists?("#{path}/SA_Output Simulation_Results_Building_Total_Energy.csv")
  File.delete("#{path}/Morris_design") if File.exists?("#{path}/Morris_design")
  FileUtils.remove_dir("#{path}/SA_Models") if Dir.exists?("#{path}/SA_Models")
end

puts 'SA.rb Completed Successfully!'