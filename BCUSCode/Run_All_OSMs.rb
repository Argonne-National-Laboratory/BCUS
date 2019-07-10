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

require 'fileutils'
require 'pathname'
require 'csv'
require 'parallel'
require 'openstudio'

# Class for running osms
class RunOSM
  def run_osm(
    model_dir, weather_dir, output_dir,
    n_runs = 1, n_processes = 0, verbose = false
  )
    FileUtils.rm_rf(output_dir) if File.exist?(output_dir)
    FileUtils.mkdir_p(output_dir)
    filepaths = Dir.glob(model_dir + '/*.osm')

    Parallel.each(
      filepaths, in_threads: n_processes, progress: "Running #{n_runs} osms"
    ) do |filepath|
      # Copy osm file
      filename = File.basename(filepath)
      puts "Queuing simulation job for #{filename}" if verbose
      original_osm_path = File.join(model_dir, filename)
      output_osm_path = File.join(output_dir, filename)
      puts "Copying #{original_osm_path} to #{output_osm_path}" if verbose
      FileUtils.copy_file(original_osm_path, output_osm_path)

      # Create workflow
      output_dir_inst = File.join(output_dir, File.basename(filename, '.*'))
      FileUtils.mkdir(output_dir_inst)
      osw_path = File.join(output_dir_inst, 'in.osw')
      workflow = OpenStudio::WorkflowJSON.new
      workflow.setSeedFile(output_osm_path)
      workflow.setWeatherFile(weather_dir)
      workflow.setOswDir(output_dir_inst)
      workflow.saveAs(osw_path)

      cli_path = OpenStudio.getOpenStudioCLI
      cmd = "\"#{cli_path}\" run -w \"#{osw_path}\""
      system(cmd)
    end
  end
end
