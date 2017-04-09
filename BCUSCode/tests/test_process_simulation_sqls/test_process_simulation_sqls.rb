####################################################################################################
# Copyright © 2016 , UChicago Argonne, LLC
# All Rights Reserved
# OPEN SOURCE LICENSE
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.  Software changes, modifications, or derivative works, should be noted with comments and the author and organization’s name.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
# 3. Neither the names of UChicago Argonne, LLC or the Department of Energy nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
#
# 4. The software and the end-user documentation included with the redistribution, if any, must include the following acknowledgment:
#
# "This product includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.”
#
# ******************************************************************************************************
# DISCLAIMER
#
# THE SOFTWARE IS SUPPLIED "AS IS" WITHOUT WARRANTY OF ANY KIND.
#
# NEITHER THE UNITED STATES GOVERNMENT, NOR THE UNITED STATES DEPARTMENT OF ENERGY, NOR UCHICAGO ARGONNE, LLC, NOR ANY OF THEIR EMPLOYEES, MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR ASSUMES ANY LEGAL LIABILITY OR RESPONSIBILITY FOR THE ACCURACY, COMPLETENESS, OR USEFULNESS OF ANY INFORMATION, DATA, APPARATUS, PRODUCT, OR PROCESS DISCLOSED, OR REPRESENTS THAT ITS USE WOULD NOT INFRINGE PRIVATELY OWNED RIGHTS.
#
# ***************************************************************************************************
#
# Modified Date and By:
# - August 2016 by Yuna Zhang
# - Created on Feb 15 2015 by Yuming Sun from Argonne National Laboratory
#
# 1. Introduction
# This is the main code used for running Bayesian calibration to generate posterior distributions and graphing results
#
# 2. Call structure
# Refer to 'Function Call Structure_Bayesian Calibration.pptx'
#
#require 'openstudio'
require 'fileutils'
#require 'rubyXL'
#require 'csv'
require_relative '../../Process_Simulation_SQLS.rb'

puts 'Starting Test of Process_Simulation_SQLs.rb'

# Acquire the path of the working directory as the test project folder.
test_path = Dir.pwd

settingsfile_path = File.absolute_path("./test_process_sqls_output_settings.xlsx")

num_test_files = Dir["test_Simulations/*.osm"].length

puts "test_path = #{test_path}"
puts "settingsfile_path = #{settingsfile_path}"
puts "num_test_files = #{num_test_files}"
puts
puts "Running Process_Simulation_SQLs"
puts

OutPut.Read(num_test_files, test_path, 'test',  settingsfile_path, verbose = true)

