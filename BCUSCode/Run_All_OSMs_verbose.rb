=begin of comments
######################################################################
#  Copyright (c) 2008-2014, Alliance for Sustainable Energy.  
#  All rights reserved.
#  
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#  
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
######################################################################

#NOTE:  Added verbose input option.  If verbose = true, we print the puts, if not, we don't 12-Sep-2015 Ralph Muehlesisen
=end

require 'fileutils'
require 'csv'
require 'openstudio'
require 'openstudio/energyplus/find_energyplus'


class RunOSM
  def run_osm(model_dir, weather_dir, output_dir, sim_num, verbose = false)

osmDir = OpenStudio::Path.new(model_dir)

weatherFileDir = OpenStudio::system_complete(OpenStudio::Path.new(weather_dir))

outputDir = OpenStudio::Path.new(output_dir)

nSim = OpenStudio::OptionalInt.new
nSim = OpenStudio::OptionalInt.new(sim_num.to_i)

OpenStudio::create_directory(outputDir)
runManagerDBPath = outputDir / OpenStudio::Path.new("RunManager.db")
puts "Creating RunManager database at " + runManagerDBPath.to_s + "." if verbose
OpenStudio::remove(runManagerDBPath) if (OpenStudio::exists(runManagerDBPath))
runManager = OpenStudio::Runmanager::RunManager.new(runManagerDBPath,true)

# find energyplus

co = OpenStudio::Runmanager::ConfigOptions.new
co.fastFindEnergyPlus

filenames = Dir.glob(osmDir.to_s + "/*.osm")


n = 0
filenames.each { |filename|
  break if (not nSim.empty?) && (nSim.get <= n)

  # copy osm file
  relativeFilePath = OpenStudio::relativePath(OpenStudio::Path.new(filename),osmDir)
  puts "Queuing simulation job for " + relativeFilePath.to_s + "." if verbose
  
  originalOsmPath = osmDir / relativeFilePath
  outputOsmPath = outputDir / relativeFilePath 
  puts "Copying '" + originalOsmPath.to_s + "' to '" + outputOsmPath.to_s + "'." if verbose
  OpenStudio::makeParentFolder(outputOsmPath,OpenStudio::Path.new,true)
  OpenStudio::copy_file(originalOsmPath,outputOsmPath)

  # create workflow
  workflow = OpenStudio::Runmanager::Workflow.new("modeltoidf->energyplus->openstudiopostprocess")
  workflow.setInputFiles(outputOsmPath,weatherFileDir)
  workflow.add(co.getTools)
  
  # create and queue job
  jobDirectory = outputOsmPath.parent_path() / OpenStudio::Path.new(outputOsmPath.stem()) / OpenStudio::Path.new("/")
  puts "Job directory will be '" + jobDirectory.to_s + "'." if verbose
  job = workflow.create(jobDirectory)
  runManager.enqueue(job, true)
  n = n + 1
}


# wait for finished
    runManager.showStatusDialog
    runManager.waitForFinished


runManager.getJobs.each { |job|

  if not job.errors.succeeded
    puts "The job in '" + job.outdir.to_s + "' did not finish successfully." 
  elsif not job.errors.warnings.empty?
    puts "The job in '" + job.outdir.to_s + "' has warnings." 
  end

  job.errors.errors.each { |err|
    puts "ERROR: " + err
  }
}
  end
end

