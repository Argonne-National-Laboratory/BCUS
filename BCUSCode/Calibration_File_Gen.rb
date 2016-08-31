=begin of comments
Copyright © 201? , UChicago Argonne, LLC
All Rights Reserved
 [Software Name, Version 1.x??]
[Optional:  Authors name and organization}
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
- Created on Feb 27, 2015 by Yuming Sun and Matt Riddle from Argonne National Laboratory

1. Introduction
This is the main code used for setting up files for running Bayesian calibration.

2. Call structure
Refer to 'Function Call Structure_Bayesian Calibration.pptx'
=end

#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for setting up files for running Bayesian calibration

require_relative 'rinruby'
require 'csv'
require 'rubyXL'
require 'optparse'

# Prepare computational data
# # y_sim, Monthly Drybuld, Monthly Solar Horizontal, Calibration parameter samples...

# Step1: Inputs from the user
options = {}

parser = OptionParser.new do |opts|

  opts.on('--projectName projectName', 'projectName') do |projectName|
    options[:projectName] = projectName
  end

  opts.on('--simElectricity simElectricity', 'simElectricity') do |simElectricity|
    options[:simElectricity] = simElectricity
  end

  opts.on('--simGas simGas', 'simGas') do |simGas|
    options[:simGas] = simGas
  end

  opts.on('--utilityData utilityData', 'utilityData') do |utilityData|
    options[:utilityData] = utilityData
  end

end
parser.parse!

path = Dir.pwd

y_sim = []
if options[:simElectricity]
  y_elec_table = CSV.read("#{path}/PreRuns_Output/#{options[:simElectricity]}", headers: false)
  y_elec_table.delete_at(0)
  y_elec_table.each do |run|
    run.each do |data|
      y_sim << data.to_f
    end
  end
end

if options[:simGas]
  y_gas_table = CSV.read("#{path}/PreRuns_Output/#{options[:simGas]}", headers: false)
  y_gas_table.delete_at(0)
  row = 0
  y_gas_table.each do |run|
    run.each do |data|
      y_sim[row] = [y_sim[row], data.to_f]
      row += 1
    end
  end
end

weather_table = CSV.read("#{path}/PreRuns_Output/Monthly_Weather.csv", headers: false)
weather_table.delete_at(0)
weather_table = weather_table.transpose
monthly_temp = weather_table[0]
monthly_solar = weather_table[1]

cal_parameter_samples_table = CSV.read("#{path}/PreRuns_Output/LHS_Samples.csv", headers: false)
cal_parameter_samples_table.delete_at(0)
cal_parameter_samples_table = cal_parameter_samples_table.transpose
cal_parameter_samples_table.delete_at(0)
cal_parameter_samples_table.delete_at(0)

cal_parameter_samples = []
cal_parameter_samples_table.each do |run|
  # read in the 12 months of samples
  for rep in 1..12 # Monthly
    cal_parameter_samples << run
  end
end

cal_data_com = []
y_sim.each_with_index do |y, index|
  cal_data_com << y + [monthly_temp[index]] + [monthly_solar[index]] + cal_parameter_samples[index]
end

def write_to_file(results, filename)
  File.open(filename, 'w+') do |f|
    results.each { |resultsRow|
      resultsRow.each { |r|
        f.write(r)
        f.write("\t")
      }
      f.write("\n")
    }
  end
  puts
  puts "run results have been written to #{filename}"
end

write_to_file(cal_data_com, "#{path}/PreRuns_Output/cal_sim_runs.txt")

#Prepare metered data
# y_meter, Monthly Drybuld, Monthly Solar Horizontal
y_meter = CSV.read("#{path}/#{options[:utilityData]}", headers: false)
y_meter.delete_at(0)
y_meter = y_meter.transpose
y_meter.delete_at(0)
y_meter = y_meter.transpose
puts y_meter.length

cal_data_field = []
y_meter.each_with_index do |y, index|
  cal_data_field << y + [monthly_temp[index]] + [monthly_solar[index]]
end

puts cal_data_field.length
write_to_file(cal_data_field, "#{path}/PreRuns_Output/cal_utility_data.txt")