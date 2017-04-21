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

# 12-Sep-2015 Ralph Muehlesisen
# Added verbose input option.  If verbose = true, we print the puts statements
# 15-Apr-2017 Ralph Muehleisen
# modified so qt_gui doesn't start and show unless -v (verbose) option is used
# 21-Apr-2017 Ralph Muehleisen
# used rubocop to lint the ruby code and clean it up

require 'fileutils'
require 'csv'
require 'openstudio'
require 'openstudio/energyplus/find_energyplus'

class RunOSM
  def run_osm(model_dir, weather_dir, output_dir, sim_num, verbose = false)
    osmDir = OpenStudio::Path.new(model_dir)

    weatherFileDir = OpenStudio.system_complete(OpenStudio::Path.new(weather_dir))

    outputDir = OpenStudio::Path.new(output_dir)

    # nSim = OpenStudio::OptionalInt.new
    nSim = OpenStudio::OptionalInt.new(sim_num.to_i)

    OpenStudio.create_directory(outputDir)
    runManagerDBPath = outputDir / OpenStudio::Path.new('RunManager.db')
    puts 'Creating RunManager database at ' + runManagerDBPath.to_s if verbose
    OpenStudio.remove(runManagerDBPath) if OpenStudio.exists(runManagerDBPath)

    # create a run manager instance and set new database = true to overwrite any existing, false to start in paused mode,
    # and ui initialize to same as verbose so it will only show up if verbose = true
    runManager = OpenStudio::Runmanager::RunManager.new(runManagerDBPath, true, false, verbose)

    # find energyplus
    co = OpenStudio::Runmanager::ConfigOptions.new
    co.fastFindEnergyPlus

    filenames = Dir.glob(osmDir.to_s + '/*.osm')

    n = 0
    filenames.each do |filename|
      break if !nSim.empty? && (nSim.get <= n)

      # copy osm file
      relativeFilePath = OpenStudio.relativePath(OpenStudio::Path.new(filename), osmDir)
      puts 'Queuing simulation job for ' + relativeFilePath.to_s if verbose

      originalOsmPath = osmDir / relativeFilePath
      outputOsmPath = outputDir / relativeFilePath
      puts "Copying '" + originalOsmPath.to_s + "' to '" + outputOsmPath.to_s if verbose
      OpenStudio.makeParentFolder(outputOsmPath, OpenStudio::Path.new, true)
      OpenStudio.copy_file(originalOsmPath, outputOsmPath)

      # create workflow
      workflow = OpenStudio::Runmanager::Workflow.new('modeltoidf->energyplus->openstudiopostprocess')
      workflow.setInputFiles(outputOsmPath, weatherFileDir)
      workflow.add(co.getTools)

      # create and queue job
      jobDirectory = outputOsmPath.parent_path / OpenStudio::Path.new(outputOsmPath.stem) / OpenStudio::Path.new('/')
      puts "Job directory will be '" + jobDirectory.to_s if verbose
      job = workflow.create(jobDirectory)
      runManager.enqueue(job, true) # queue up a job and process even if its out of date
      n += 1
    end

    runManager.showStatusDialog if verbose
    runManager.waitForFinished

    runManager.getJobs.each do |job|
      if !job.errors.succeeded
        puts "The job in '" + job.outdir.to_s + "' did not finish successfully."
      elsif !job.errors.warnings.empty?
        puts "The job in '" + job.outdir.to_s + "' has warnings."
      end

      job.errors.errors.each do |err|
        puts 'ERROR: ' + err
      end
    end
  end
end
