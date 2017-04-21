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
#    author and organization’s name.
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
#     Contract No. DE-AC02-06CH11357 with the Department of Energy.”
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
# - Updated on August 2016 by Yuna Zhang from Argonne National Laboratory
# - Updated on 10-Aug-2015 by Ralph Muehleisen from Argonne National Laboratory
# - Created on Feb 27 2015 by Yuming Sun and Matt Riddle from Argonne
#
# 1. Introduction
# This is the main code used for generating random variables using LHS

#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for LHS and Morris method generated random variables

# 10-Aug-2015 Ralph Muehleisen
# Added seed and verbose to call

# 08-Apr-2017 Ralph Muehleisen
# combined LHS_gen.rb and Morris.rb into one .rb file and pulled cdf_inverse
# out of each Class and into a common def to eliminate identical code in two
# classes

require_relative 'rinruby'
require 'csv'

def cdf_inverse(lhs_random_num, prob_distribution)
  R.assign('q', lhs_random_num)
  case prob_distribution[1]
  when /Normal Absolute/
    R.assign('mean', prob_distribution[2])
    R.assign('std', prob_distribution[3])
    R.eval 'samples<- qnorm(q,mean,std)'

  when /Normal Relative/
    R.assign('mean', prob_distribution[2] * prob_distribution[0])
    R.assign('std', prob_distribution[3] * prob_distribution[0])
    R.eval 'samples<- qnorm(q,mean,std)'

  when /Uniform Absolute/
    R.assign('min', prob_distribution[4])
    R.assign('max', prob_distribution[5])
    R.eval 'samples<- qunif(q,min,max)'

  when /Uniform Relative/
    R.assign('min', prob_distribution[4] * prob_distribution[0])
    R.assign('max', prob_distribution[5] * prob_distribution[0])
    R.eval 'samples<- qunif(q,min,max)'

  when /Triangle Absolute/
    R.assign('min', prob_distribution[4])
    R.assign('max', prob_distribution[5])
    R.assign('mode', prob_distribution[2])
    R.eval 'library("triangle")'
    R.eval 'samples<- qtriangle(q,min,max,mode)'

  when /Triangle Relative/
    R.assign('min', prob_distribution[4] * prob_distribution[0])
    R.assign('max', prob_distribution[5] * prob_distribution[0])
    R.assign('mode', prob_distribution[2] * prob_distribution[0])
    R.eval 'library("triangle")'
    R.eval 'samples<- qtriangle(q,min,max,mode)'

  when /LogNormal Absolute/
    R.assign('log_mean', prob_distribution[2])
    R.assign('log_std', prob_distribution[3])
    R.eval 'samples<- qlnorm(q,log_mean,log_std)'
  else
    R.samples = []
  end
  R.samples
end # cdf_inverse

# This class is used for generating random numbers and latin hypercube samples
class LHSGenerator
  def random_num_generate(n_runs, n_parameters, output_folder, verbose = false, randseed = 0)
    R.assign('numRuns', n_runs)
    R.assign('numParams', n_parameters)
    R.assign('randseed', randseed) # set the random seed.

    R.eval <<-RCODE
      library("lhs")
      if (randseed!=0){
          set.seed(randseed)
      } else {
          set.seed(NULL)
      }
      lhs <- randomLHS (numRuns,numParams)
    RCODE
    lhs_table = R.lhs.transpose

    CSV.open("#{output_folder}/Random_LHS_Samples.csv", 'wb')
    CSV.open("#{output_folder}/Random_LHS_Samples.csv", 'a+') do |csv|
      (0..lhs_table.row_count).each do |row_index|
        csv << lhs_table.row(row_index).to_a
      end
    end

    puts "Random_LHS_Samples.csv with the size of #{lhs_table.row_count} rows and #{lhs_table.column_count} columns is generated" if verbose
    lhs_table
  end # random_num_generate

  def lhs_samples_generator(uqtable_folder, file_name, n_runs, output_folder, verbose = false, randseed = 0)
    table = CSV.read("#{uqtable_folder}/#{file_name}")
    n_parameters = table.count - 1 # the first row is the header
    lhs_random_table = random_num_generate(n_runs, n_parameters, output_folder, verbose, randseed)
    row_index = 0
    CSV.open("#{output_folder}/LHS_Samples.csv", 'wb')
    CSV.open("#{output_folder}/LHS_Samples.csv", 'a+') do |csv|
      header = table[0].to_a[0, 2]
      (1..n_runs).each do |sample_index|
        header << "Run #{sample_index}"
      end
      csv << header
      CSV.foreach("#{uqtable_folder}/#{file_name}", headers: true) do |parameter|
        prob_distribution = [parameter['Parameter Base Value'].to_f,
                             parameter['Distribution'],
                             parameter['Mean or Mode'].to_f,
                             parameter['Std Dev'].to_f,
                             parameter['Min'].to_f,
                             parameter['Max'].to_f]
        q = lhs_random_table.row(row_index).to_a
        csv << table[row_index + 1].to_a[0, 2] + cdf_inverse(q, prob_distribution)
        row_index += 1
      end
    end
    if verbose
      puts 'LHS_Samples.csv is generated and saved to the folder!'
      puts "It includes #{n_runs} simulation runs"
    end
  end # lhs_samples_generator
end

# Compute the sensitivities for the given model via the Morris method
class Morris
  # model is a method (obtained by a call to method(:mymodelfunction)) representing the model to test
  # model should take, as input, a vector of length n_params
  # n_repetitions is the number of repetitions that will be performed during the Morris sampling
  # param_lower_bounds and param_upper_bounds are both vectors of length n_params, giving the upper
  # and lower bounds for each parameter
  #
  #
  # example usage:
  #
  # def myfun(x):
  #	return x[0]+10*x[1]
  # end
  # Morris.compute_sensitivities(methd(:myfun), 2, 10, [0,0], [1,1])
  # => [1.0, 10.0]
  #

  def design_matrix(file_path, file_name, morris_R, morris_levels, randseed = 0, verbose = false)
    # file_path = path to SA_output directory
    # file_name = full path name to UQ output file
    # morris_R = number of morris repetitions (routes/tracks)
    # morris_L = number of morris levels
    puts "Randseed = #{randseed}" if verbose
    table = CSV.read(file_name.to_s)
    n_parameters = table.count - 1 # the first row is the header
    R.assign('randseed', randseed) # set the random seed.
    R.assign('n', n_parameters)
    R.assign('mR', morris_R)

    R.eval <<-RCODE
      library("sensitivity")
      if (randseed!=0){
        set.seed(randseed)
      } else{
        set.seed(NULL)
      }
      design <- morris(NULL, n, mR, binf=0.05, bsup=0.95,
        scale=FALSE, design = list(type = "oat", levels = #{morris_levels}, grid.jump = #{(morris_levels / 2 + 0.5).to_i}))
      X <- design$X
      save (design, file="#{file_path}/Morris_design")
    RCODE

    design_matrix = R.X

    row_index = 0
    CSV.open("#{file_path}/Morris_0_1_Design.csv", 'wb')
    CSV.open("#{file_path}/Morris_0_1_Design.csv", 'a+') do |csv|
      while row_index <= design_matrix.row_count
        csv << design_matrix.row(row_index).to_a
        row_index += 1
      end
    end

    # CDF transform
    row_index = 0
    CSV.open("#{file_path}/Morris_CDF_Tran_Design.csv", 'wb')
    CSV.open("#{file_path}/Morris_CDF_Tran_Design.csv", 'a+') do |csv|
      header = table[0].to_a[0, 2]
      (1..design_matrix.row_count).each do |sample_index|
        header << "Run #{sample_index}"
      end
      csv << header

      CSV.foreach(file_name.to_s, headers: true, converters: :numeric) do |parameter|
        prob_distribution = [
          parameter['Parameter Base Value'].to_f,
          parameter['Distribution'],
          parameter['Mean or Mode'].to_f,
          parameter['Std Dev'].to_f,
          parameter['Min'].to_f,
          parameter['Max'].to_f
        ]
        q = design_matrix.transpose.row(row_index).to_a
        csv << table[row_index + 1].to_a[0, 2] + cdf_inverse(q, prob_distribution)
        row_index += 1
      end
    end
  end # design matrix

  def compute_sensitivities(model_response_file, output_folder, uq_file_name,
                            verbose = false, maxstring = 60)
    # verbose
    # maxstring = maximum size of the parameter+object string in characters, default = 50
    R.assign('y_file', model_response_file)
    R.assign('output_folder', output_folder)
    R.assign('uq_file_name', uq_file_name)
    R.assign('maxstring', maxstring)
    if verbose
      R.assign('verbose', 1)
    else
      R.assign('verbose', 0)
    end

    R.eval <<-RCODE
      table_name<-read.csv(uq_file_name, header = TRUE,fill = TRUE, strip.white = TRUE, stringsAsFactors = TRUE)

      # the following combines columns 1and column 2 into one string for the full
      # name of the parameter for sensitivity analysis, truncates to first maxstring char
			# takes the transpose and converts back to a data frame
      b = data.matrix(t(substr(paste(table_name[[1]],table_name[[2]],sep = ": "),1,maxstring)))
      #bframe = data.frame(t(b))
      library("sensitivity")
      load("#{output_folder}/Morris_design")
      Table <- read.csv(y_file,header=TRUE,check.names=FALSE) # use check.names=FALSE to keep spaces in output names
      Tablenames <- names(Table)
      Filenames <- gsub(' ','.',names(Table))

      Y <- data.matrix(Table)

      outarray = list()

      pdf(sprintf("%s/Sensitivity_Plots.pdf",output_folder))

      for (i in 1:dim(Y)[2]){
        # the following uses the data in Y and the morris info in design to generate the output table in design
				tell(design,Y[, i])

				# extract the data as per the instructions in the sensitivity package documentation
				mu <- apply(design$ee, 2, mean)
				mu.star <- apply(design$ee, 2, function(x) mean(abs(x)))
				sigma <- apply(design$ee, 2, sd)
				morrisout <- data.frame(mu, mu.star, sigma, row.names = colnames(design$ee))
        outarray[[i]] = morrisout

        plot(design, main = Tablenames[i])

      tablename = sprintf("SA_wrt_%s.csv", Filenames[i])
				write.csv(morrisout, file = sprintf("%s/%s", output_folder, tablename), row.names = b)

      }
      graphics.off() # use instead of dev.off() to avoid printout

      if (verbose > 0){

        # print table mapping X1, X2, etc to variable names
        cat("\n Sensitivity Variable Table\n")
        print(data.frame(t(b), row.names = colnames(design$ee)))

        # print out the sensitivity tables
        cat("\nSensitivity Tables\n")
        names(outarray) <- names(Table)  # rename the tables using sensitivity table names instead [[1]], [[2]], etc.
        print(outarray)
      }

    RCODE
  end # def compute_sensitivities
end # Class Morris
