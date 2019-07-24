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
# 22-Apr-2017 RTM Created when refactoring main UA, SA, BC routines

# 1. Introduction
# This file includes several definitions/modules that are used by other
# routines in the BCUS package

#===============================================================%
#     author: Ralph Muehleisen                        %
#     date: 22-Apr-2017
#===============================================================%

# several definitions that are commonly used by the differn

require 'rubyXL'
require 'rinruby'
require 'fileutils'
require 'csv'

def parse_argv(cmd_option, extension, error_msg)
  if cmd_option.nil?
    regex = Regexp.new(extension)
    return ARGV.grep(regex)[0] if ARGV.grep(regex).any?
    puts error_msg + "\n!!!Terminating Execution!!!"
    abort
  else
    return cmd_option
  end
end

# Define prompt to wait for user to enter y or Y to continue for interactive
def wait_for_y(message = nil)
  puts message unless message.nil?
  check = 'n'
  while check != 'y' && check != 'Y'
    print "Please enter 'Y' or 'y' to continue; " \
      "'n', 'N', or 'CTRL-Z' to quit: "
    # Read from keyboard, strip spaces and convert to lower case
    check = $stdin.gets.strip.downcase
    abort if check == 'n'
  end
end

# Check for the existence of an OSM file and if one exists, load it
# If not, print an error message and abort
def read_osm_file(filename, verbose)
  if File.exist?(filename)
    model = OpenStudio::Model::Model.load(filename).get
    puts "Using OSM file #{filename}" if verbose
  else
    puts "OpenStudio OSM file #{filename} not found!"
    abort
  end
  return model
end

def check_file_exist(filename, file_string, verbose = false)
  if File.exist?(filename)
    puts "Using #{file_string} #{filename}" if verbose
  else
    puts "#{file_string} #{filename} not found!"
    abort
  end
end

def read_workbook(filename, sheet)
  # Read a single sheet of a workbook of name filename
  workbook = RubyXL::Parser.parse(filename)
  table = []
  workbook[sheet].each do |row|
    table_row = []
    row.cells.each { |cell| table_row.push(cell.value) }
    table.push(table_row)
  end
  return table
end

def max_column_width(table)
  maxes = Array.new(table[0].length, 0)
  table.each do |row|
    row.each_with_index do |value, index|
      maxes[index] = [maxes[index] || 0, value.to_s.length].max
    end
  end
  return maxes
end

def pp_table(table)
  maxes = max_column_width(table)
  table.each do |row|
    row.each_with_index do |col, index|
      print "#{col.to_s.ljust(maxes[index])} "
    end
    puts
  end
end

def read_table(filename, file_string, file_type, verbose)
  if File.exist?(filename)
    puts "Using #{file_string} = #{filename}" if verbose
    table = read_workbook(filename, file_type)
    pp_table(table) if file_type == 'Meters' && verbose
  else
    puts "#{filename} was NOT found!"
    abort
  end
  return table
end

def read_prior_table(filename, verbose)
  if File.exist?(filename)
    puts "Using prior distribution file = #{filename}" if verbose
    uq_table_full = CSV.read(filename).delete_at(0)
    uq_table = []
    uq_table_full.each do |uq_param|
      case uq_param[0]
      when /HeatingSetpoint/
        table_row =
          %w[ZoneControl ThermostatSettings ThermostatSetpointHeating On]
        table_row.push(*uq_param[3..-1])
        uq_table.push(table_row)
      when /CoolingSetpoint/
        table_row =
          %w[ZoneControl ThermostatSettings ThermostatSetpointCooling On]
        table_row.push(*uq_param[3..-1])
        uq_table.push(table_row)
      end
    end
  else
    puts "#{filename} was NOT found!"
    abort
  end
  return uq_table
end

def add_to_table(table_in, table_file)
  if File.exist?(table_file)
    # read in the table
    read_in = CSV.read(table_file, headers: false)
    read_in.delete_at(0) # delete the header of the table
    temp = read_in.transpose
    temp.delete_at(0) # get rid of the first column of the original table
    table_in << temp.flatten # add a new to the input table from the
  end
  return table_in
end

def get_table_length(table_file)
  if File.exist?(table_file)
    read_in = CSV.read(table_file, headers: false)
    read_in.delete_at(0) # delete the header of the table
    length = read_in.length
  else
    length = nil
  end
  return length
end

def get_y_sim(elec_file, gas_file)
  y_sim = []
  y_sim = add_to_table(y_sim, elec_file)
  y_sim = add_to_table(y_sim, gas_file)
  y_sim = y_sim.transpose
  return y_sim
end

def read_monthly_weather(weather_file)
  weather_table = CSV.read(weather_file, headers: false)
  weather_table.delete_at(0)
  weather_table = weather_table.transpose
  temp = weather_table[0]
  solar = weather_table[1]
  return [temp, solar]
end

def get_cal_sim_data(y_sim, y_length, lhs_table, temp, solar)
  lhs_table = lhs_table.to_a
  lhs_table.delete_at(0)
  samples_table = lhs_table.transpose
  2.times { samples_table.delete_at(0) }

  samples = []
  samples_table.each do |run|
    (1..y_length).each { samples << run }
  end

  cal_sim_data = []
  y_sim.each_with_index do |y, index|
    cal_sim_data << y + [temp[index]] + [solar[index]] + samples[index]
  end
  return cal_sim_data
end

def get_cal_field_data(utility_file, temp, solar, verbose)
  # Read in the utility meter data
  y_meter = CSV.read(utility_file, headers: false)
  y_meter.delete_at(0)
  y_meter = y_meter.transpose
  y_meter.delete_at(0)
  y_meter = y_meter.transpose
  puts "#{y_meter.length} months of data read from #{utility_file}" if verbose

  # Generate the cal_field_data as a table with y_meter, monthly drybulb,
  # monthly horizontal solar
  cal_field_data = []
  y_meter.each_with_index do |y, index|
    cal_field_data << y + [temp[index]] + [solar[index]]
  end
  puts "cal_field_data length = #{cal_field_data.length}" if verbose
  return cal_field_data
end

def delete_files(folder, file_list, verbose = false)
  file_list.each do |file|
    full_file_path = File.join(folder, file)
    File.delete(full_file_path) if File.exist?(full_file_path)
    puts "removed file #{full_file_path}" if verbose
  end
end

def delete_folder(folder, verbose = false)
  FileUtils.remove_dir(folder) if Dir.exist?(folder)
  puts "removed folder #{folder}" if verbose
end

def add_reporting_meters_to_model(model, meters_table)
  # add reporting meters to model
  (1..(meters_table.length - 1)).each do |meter_index|
    meter = OpenStudio::Model::OutputMeter.new(model)
    meter.setName(meters_table[meter_index][0].to_s)
    meter.setReportingFrequency(meters_table[meter_index][1].to_s)
  end
end

def add_output_variables_to_model(model, output_variable, frequency)
  # add an OS Model output variable with the frequency given by 'frequency'
  variable = OpenStudio::Model::OutputVariable.new(output_variable, model)
  variable.setReportingFrequency(frequency)
end

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

def extract_samples(samples_table)
  # Parse the sample table of format: name, type, values to get a list
  # of all the names and types

  # Convert CSV table to a real array
  samples_array = samples_table.to_a
  # Transpose to get better access to columns and put in
  param_values = samples_array.transpose
  # Types are in the 1st column of samples, 1st row of transpose
  param_types = param_values[0]
  # Names are the 2nd column of samples, 2nd row of transpose
  param_names = param_values[1]
  2.times { param_values.delete_at(0) }
  # Convert entire array to floats
  param_values = param_values.map { |arr| arr.map(&:to_f) }

  return [param_names, param_types, param_values]
end
