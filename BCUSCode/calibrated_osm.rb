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

# Modified Date and By:
# - August 2016 by Yuna Zhang
# - Created on Feb 27, 2015 by Yuming Sun and Matt Riddle from Argonne National
#   Laboratory

#===============================================================%
#     author: Yuming Sun and Matt Riddle                        %
#     date: Feb 27, 2015                                        %
#===============================================================%

require 'fileutils'
require 'openstudio'

require_relative 'run_osm'
require_relative 'uncertain_parameters'
require_relative 'process_simulation_sqls'

# Class to generate and run calibrated model
class CalibratedOSM
  def gen_and_sim(
    osm_file, weather_file, prior_file, post_file,
    meter_set_file, cal_model_file, output_folder, verbose
  )

    model = OpenStudio::Model::Model.load(osm_file).get

    params = CSV.read(prior_file, headers: true)
    param_names = params['Object in the model']
    param_types = params['Parameter Type']

    post = CSV.read(post_file, headers: true, converters: :numeric)
    headers = post.headers()
    post_average = [0] * headers.length
    headers.each_with_index do |header, index|
      post_average[index] = average(post[header])
    end

    uncertainty_parameters = UncertainParameters.new
    param_value = post_average
    uncertainty_parameters.apply(model, param_types, param_names, param_value)

    # Add reporting meters
    meters_table = read_meters_table(meter_set_file, verbose)
    add_reporting_meters_to_model(model, meters_table)

    # Add weather variable reporting to model and set its frequency
    add_output_variable_to_model(
      model, 'Site Outdoor Air Drybulb Temperature', 'Monthly'
    )
    add_output_variable_to_model(
      model, 'Site Ground Reflected Solar Radiation Rate per Area', 'Monthly'
    )

    model.save(cal_model_file, true)

    sim_dir = File.join(output_folder, 'Cal_Simulations')
    runner = RunOSM.new
    runner.run_osm(output_folder, weather_file, sim_dir)

    # Read Simulation Results
    OutPut.read(sim_dir, meter_set_file, output_folder)
  end
end

def average(one_d_array)
  sum = 0.0
  n = one_d_array.length
  one_d_array.each do |val|
    begin
      Float(val)
    rescue StandardError
      n -= 1
    else
      sum += val
    end
  end
  return sum / n
end
