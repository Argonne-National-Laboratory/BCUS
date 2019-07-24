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
# - Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
# - Updated on 10-Aug-2015 by Ralph Muehleisen from Argonne National Laboratory
# - Created on Feb 27 2015 by Yuming Sun and Matt Riddle from Argonne National
#   Laboratory

# 1. Introduction
# This is the main code used for generating random variables using LHS

#===============================================================%
#     author: Yuming Sun and Matt Riddle                        %
#     date: Feb 27, 2015                                        %
#===============================================================%

# Main code used for generated random variables

# 10-Aug-2015 Ralph Muehleisen
# Added seed and verbose to call

require 'fileutils'
require 'rinruby'
require 'csv'

require_relative 'bcus_utils'

# rubocop:disable Lint/UselessAssignment
R.echo(enabled = false)
# rubocop:enable Lint/UselessAssignment

# Class to generate Latin Hypercube design sample
class LHD
  def random_num_generate(
    n_runs, n_parameters, out_dir, randseed = 0, verbose = false
  )
    R.assign('numRuns', n_runs)
    R.assign('numParams', n_parameters)
    R.assign('randseed', randseed) # set the random seed.

    R.eval <<-RCODE
      library("lhs")
      if (randseed!=0) {
          set.seed(randseed)
      } else {
          set.seed(NULL)
      }
      lhs <- randomLHS(numRuns, numParams)
    RCODE
    lhs_table = R.lhs.transpose

    row_index = 0
    CSV.open(File.join(out_dir, 'Random_LHD_Samples.csv'), 'wb') do |csv|
      (0..lhs_table.row_count).each do |row_index|
        csv << lhs_table.row(row_index).to_a
      end
    end
    if verbose
      puts "Random_LHD_Samples.csv with the size of #{lhs_table.row_count} "\
        "rows and #{lhs_table.column_count} columns is generated"
    end
    return lhs_table
  end

  def lhd_samples_generator(
    uq_file, n_runs, out_dir, randseed = 0, verbose = false
  )
    table = CSV.read(uq_file.to_s)
    n_parameters = table.count - 1 # the first row is the header
    lhs_random_table = random_num_generate(
      n_runs, n_parameters, out_dir, randseed, verbose
    )

    row_index = 0
    CSV.open(File.join(out_dir, 'LHD_Sample.csv'), 'wb') do |csv|
      header = table[0].to_a[0, 2]
      (1..n_runs).each { |sample_index| header << "Run #{sample_index}" }
      csv << header
      CSV.foreach(
        uq_file.to_s, headers: true, converters: :numeric
      ) do |parameter|
        prob_distribution = [
          parameter['Parameter Base Value'],
          parameter['Distribution'],
          parameter['Mean or Mode'],
          parameter['Std Dev'],
          parameter['Min'],
          parameter['Max']
        ]
        q = lhs_random_table.row(row_index).to_a
        csv << (
          table[row_index + 1].to_a[0, 2] + cdf_inverse(q, prob_distribution)
        )
        row_index += 1
      end
    end
    return unless verbose # using guard clause as per ruby style guide
    puts 'LHD_Sample.csv has been generated and saved!' if verbose
    puts "It includes #{n_runs} simulation runs" if verbose
  end
end
