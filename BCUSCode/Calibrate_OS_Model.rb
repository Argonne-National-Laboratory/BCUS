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
- August 2016 by Yuna Zhang
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

require 'openstudio'
#require_relative 'Run_All_OSMs'
require_relative 'Run_All_OSMs_verbose'
require_relative 'Uncertain_Parameters'
#require_relative 'Read_Calibrated_Sim_SQL'
require_relative 'Process_Simulation_SQLs'

class Calibrated_OSM
  def gen_and_sim(osm_model_file, weather_file, prior_file, posterior_file,
                  meter_set_file, calibrated_model_file, calibrated_model_name, run_manager_folder, verbose = false)
    posterior = CSV.read(posterior_file, headers: true, converters: :numeric)
    headers = posterior.headers()
    
    puts "Entering gen_and_sim" if verbose

    def is_number?(object)
      true if Float(object) rescue false
    end

    def average(one_d_array)
      sum = 0.0
      n = one_d_array.length()
      one_d_array.each do |val|
        if is_number?(val)
          sum += val
        else
          n -= 1
        end
      end
      return sum/n
    end
    
    posterior_average = [0]*headers.length()
    headers.each_with_index do |header, index|
      posterior_average[index] = average(posterior[header])
    end

    model = OpenStudio::Model::Model::load(osm_model_file).get
    parameters = CSV.read(prior_file, headers: true)
    parameter_names = parameters['Object in the model']
    parameter_types = parameters['Parameter Type']

    uncertainty_parameters = UncertainParameters.new
    parameter_value = posterior_average
    uncertainty_parameters.apply(model, parameter_types, parameter_names, parameter_value)
    workbook = RubyXL::Parser.parse(meter_set_file)
    meters_table = Array.new
    meters_table_row = Array.new
    workbook['Meters'].each { |row|
      meters_table_row = []
      row.cells.each { |cell|
        meters_table_row.push(cell.value)
      }
      meters_table.push(meters_table_row)
    }

    (1..(meters_table.length-1)).each { |meter_index|
      meter = OpenStudio::Model::Meter.new(model)
      meter.setName("#{meters_table[meter_index][0]}")
      meter.setReportingFrequency("#{meters_table[meter_index][1]}")
    }

    variable = OpenStudio::Model::OutputVariable.new('Site Outdoor Air Drybulb Temperature', model)
    variable.setReportingFrequency('Monthly')
    variable = OpenStudio::Model::OutputVariable.new('Site Ground Reflected Solar Radiation Rate per Area', model)
    variable.setReportingFrequency('Monthly')

    model.save(calibrated_model_file, true)

    runner = RunOSM.new()
    runner.run_osm(run_manager_folder, weather_file, "#{run_manager_folder}/Cal_Simulations", 1)

    # Read Simulation Results
    sql_file_path = "#{run_manager_folder}/Simulations/#{calibrated_model_name}/ModelToIdf/EnergyPlus-0/eplusout.sql"
    output_folder = run_manager_folder
    puts output_folder
   #OutPut.Read(sql_file_path, meter_set_file, output_folder)
    OutPut.Read(1, project_path, 'Cal',  settingsfile_path, verbose)
    
    ### fixing the OutPut.Read

  end
end
