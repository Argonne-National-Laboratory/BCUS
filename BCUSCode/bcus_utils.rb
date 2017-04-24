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
# This file includes several definitions/modules  that are used by other
# routines in the BCUS package

#===============================================================%
#     author: Ralph Muehleisen                        %
#     date: 22-Apr-2017
#===============================================================%

# several definitions that are commonly used by the differn

require 'rubyXL'
require 'fileutils'

# define prompt to wait for user to enter y or Y to continue for interactive
def wait_for_y(message = nil)
  puts message unless message.nil?
  check = 'n'
  while check != 'y' && check != 'Y'
    print "Please enter 'Y' or 'y' to continue; 'n', 'N', or 'CTRL-Z' to quit: "
    # read from keyboard, strip spaces and convert to lower case
    check = $stdin.gets.strip.downcase
    abort if check == 'n'
  end
end

# check for the existence of an OSM file and if one exists, load it
# if not, print an error message and abort
def read_osm_file(filename, verbose)
  if File.exist?(filename)
    model = OpenStudio::Model::Model.load(filename).get
    puts "Using OSM file #{filename}" if verbose
  else
    puts "OpenStudio OSM file #{filename} not found!"
    abort
  end
  model
end

# check for the existence of an EPW file, if it doesn't, print error and abort
def check_epw_file(filename, verbose)
  if File.exist?(filename)
    puts "Using EPW file #{filename}" if verbose
  else
    puts "EPW file #{filename} not found!"
    abort
  end
end

def read_workbook(filename, sheet)
  # read a single sheet of a workbook of name filename
  workbook = RubyXL::Parser.parse(filename)
  table = []
  workbook[sheet].each do |row|
    table_row = []
    row.cells.each do |cell|
      table_row.push(cell.value)
    end
    table.push(table_row)
  end
  table
end

def max_column_width(table)
  maxes = Array.new(table[0].length, 0)
  table.each do |row|
    row.each_with_index do |value, index|
      maxes[index] = [maxes[index] || 0, value.to_s.length].max
    end
  end
  maxes
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

def read_meters_table(filename, verbose)
  if File.exist?(filename)
    puts "Using Output Settings = #{filename}" if verbose
    meters_table = read_workbook(filename, 'Meters')
    pp_table(meters_table) if verbose
  else
    puts "#{settingsfile} was NOT found!"
    abort
  end
  meters_table
end

def read_uq_table(filename, verbose)
  if File.exist?(filename)
    puts "Using UQ repository = #{filename}" if verbose
    uq_table = read_workbook(filename, 'UQ')
  else
    puts "#{filename} was NOT found!"
    abort
  end
  uq_table
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
  table_in
end

def get_table_length(table_file)
  if File.exist?(table_file)
    read_in = CSV.read(table_file, headers: false)
    read_in.delete_at(0) # delete the header of the table
    length = read_in.length
  else
    length = nil
  end
  length
end

def read_monthly_weather_file(weather_file)
  weather_table = CSV.read(weather_file, headers: false)
  weather_table.delete_at(0)
  weather_table = weather_table.transpose
  monthly_temp = weather_table[0]
  monthly_solar = weather_table[1]
  [monthly_temp, monthly_solar]
end

def parse_argv(cmd_option, extension, error_msg)
  if cmd_option.nil?
    regex = Regexp.new(extension)
    return ARGV.grep(regex)[0] if ARGV.grep(regex).any?
    puts error_msg + "\n!!!Terminating Execution!!!"
    abort
  else
    cmd_option
  end
end

def delete_files(folder, file_list, verbose = false)
  file_list.each do |file|
    full_file_path = "#{folder}/#{file}"
    File.delete(full_file_path) if File.exist?(full_file_path)
    puts "removed file #{full_file_path}" if verbose
  end
end

def delete_folder(folder, verbose = false)
  FileUtils.remove_dir(folder) if Dir.exist?(folder)
  puts "removed folder #{folder}" if verbose
end

def add_output_variable_to_model(model, output_variable, frequency)
  # add an OS Model output variable with the frequency given by 'frequency'
  variable = OpenStudio::Model::OutputVariable.new(output_variable, model)
  variable.setReportingFrequency(frequency)
end

def add_reporting_meters_to_model(model, meters_table)
  # add reporting meters to model
  (1..(meters_table.length - 1)).each do |meter_index|
    meter = OpenStudio::Model::Meter.new(model)
    meter.setName(meters_table[meter_index][0].to_s)
    meter.setReportingFrequency(meters_table[meter_index][1].to_s)
  end
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

# def convert_meter_names_to_filenames(_input_meter_list)
#   output_list = []
#   input_list.each_with_index do |_filename, _index|
#     outname = "Meter_#{meters_table[meter_index][0].split(':')[0]}_#{meters_table[meter_index][0].split(':')[1]}"
#   end
# end

# def cal_uniform_samples_generator(uqtablefilePath, file_name, n_runs, outputfilePath, verbose=false, randseed=0)
#   table = CSV.read("#{uqtablefilePath}/#{file_name}")
#   n_parameters = table.count-1 # the first row is the header
#   lhs_random_table = random_num_generate(n_runs, n_parameters, outputfilePath, verbose, randseed)
#   row_index = 0
#   CSV.open("#{outputfilePath}/LHS_Samples.csv", 'wb')
#   CSV.open("#{outputfilePath}/LHS_Samples.csv", 'a+') do |csv|
#     header = table[0].to_a[0, 2]
#     (1..n_runs).each { |sample_index|
#       header << "Run #{sample_index}"
#     }
#     csv << header
#     CSV.foreach("#{uqtablefilePath}/#{file_name}", headers: true, converters: :numeric) do |parameter|
#       prob_distribution = [parameter['Parameter Base Value'],
#                            'Uniform Absolute',
#                            parameter['Mean or Mode'],
#                            parameter['Std Dev'],
#                            parameter['Min'],
#                            parameter['Max']]
#       q = lhs_random_table.row(row_index).to_a
#       csv << table[row_index+1].to_a[0, 2] + cdf_inverse(q, prob_distribution)
#       row_index +=1
#     end
#   end
#   if verbose
#     puts 'LHS_Samples.csv is generated and saved to the folder!'
#     puts "It includes #{n_runs} simulation runs"
#   end
# end
#
