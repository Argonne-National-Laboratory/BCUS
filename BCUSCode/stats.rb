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

require 'fileutils'
require 'rinruby'
require 'csv'

require_relative 'bcus_utils'

# rubocop:disable Lint/UselessAssignment
R.echo(enabled = false)
# rubocop:enable Lint/UselessAssignment

# Class to perform statistical analysis
class Stats
  def generate_design(
    n_vars, design_type, params, out_dir, randseed = 0, verbose = false
  )
    R.assign('numVars', n_vars)
    R.assign('randseed', randseed)

    case design_type
    when 'LHD'
      R.assign('numRuns', params[:n_runs])
      R.eval <<-RCODE
        library("lhs")
        if (randseed!=0) {
            set.seed(randseed)
        } else {
            set.seed(NULL)
        }
        lhs <- randomLHS(numRuns, numVars)
      RCODE
      design = R.lhs
    when 'Morris'
      R.assign('mR', params[:morris_r])
      R.assign('mL', params[:morris_l])
      R.assign('mJ', params[:morris_l]**2 / 2 / (params[:morris_l] - 1))
      R.eval <<-RCODE
        library("sensitivity")
        if (randseed!=0) {
          set.seed(randseed)
        } else {
          set.seed(NULL)
        }
        design <- morris(
          NULL, numVars, mR, binf=0.05, bsup=0.95, scale=FALSE,
          design = list(type = "oat", levels = mL, grid.jump = mJ)
        )
        X <- design$X
        save(design, file="#{out_dir}/Morris_design")
      RCODE
      design = R.X
    end

    CSV.open(File.join(out_dir, "#{design_type}_Design.csv"), 'wb') do |csv|
      (0..design.row_count).each { |index| csv << design.row(index).to_a }
    end
    if verbose
      puts "#{design_type}_Design.csv with the size of #{design.row_count} " \
        "rows and #{design.column_count} columns is generated"
    end
    return design
  end

  def samples_generator(
    uq_file, design_type, params, out_dir, randseed = 0, verbose = false
  )
    puts "Randseed = #{randseed}" if verbose
    table = CSV.read(uq_file.to_s)
    # The first row is the header
    n_variables = table.count - 1
    design = generate_design(
      n_variables, design_type, params, out_dir, randseed, verbose
    )

    out_filename = "#{design_type}_Sample.csv"
    row_index = 0
    CSV.open(File.join(out_dir, out_filename), 'wb') do |csv|
      # Headers
      header = table[0].to_a[0, 2]
      (1..design.row_count).each { |index| header << "Run #{index}" }
      csv << header
      # Samples
      CSV.foreach(uq_file.to_s, headers: true, converters: :numeric) do |param|
        prob_distribution = [
          param['Parameter Base Value'],
          param['Distribution'],
          param['Mean or Mode'],
          param['Std Dev'],
          param['Min'],
          param['Max']
        ]
        q = design.transpose.row(row_index).to_a
        csv << (
          table[row_index + 1].to_a[0, 2] + cdf_inverse(q, prob_distribution)
        )
        row_index += 1
      end
    end
    return unless verbose # using guard clause as per ruby style guide
    puts "#{out_filename} has been generated and saved!" if verbose
    puts "It includes #{design.row_count} simulation runs" if verbose
  end

  def cdf_inverse(lhs_random_num, prob_distribution)
    R.assign('q', lhs_random_num)
    case prob_distribution[1]
    when /Normal Absolute/
      R.assign('mean', prob_distribution[2])
      R.assign('std', prob_distribution[3])
      R.eval 'samples <- qnorm(q, mean, std)'

    when /Normal Relative/
      R.assign('mean', prob_distribution[2] * prob_distribution[0])
      R.assign('std', prob_distribution[3] * prob_distribution[0])
      R.eval 'samples <- qnorm(q, mean, std)'

    when /Uniform Absolute/
      R.assign('min', prob_distribution[4])
      R.assign('max', prob_distribution[5])
      R.eval 'samples <- qunif(q, min, max)'

    when /Uniform Relative/
      R.assign('min', prob_distribution[4] * prob_distribution[0])
      R.assign('max', prob_distribution[5] * prob_distribution[0])
      R.eval 'samples <- qunif(q, min, max)'

    when /Triangle Absolute/
      R.assign('min', prob_distribution[4])
      R.assign('max', prob_distribution[5])
      R.assign('mode', prob_distribution[2])
      R.eval 'library("triangle")'
      R.eval 'samples <- qtriangle(q, min, max, mode)'

    when /Triangle Relative/
      R.assign('min', prob_distribution[4] * prob_distribution[0])
      R.assign('max', prob_distribution[5] * prob_distribution[0])
      R.assign('mode', prob_distribution[2] * prob_distribution[0])
      R.eval 'library("triangle")'
      R.eval 'samples <- qtriangle(q, min, max, mode)'

    when /LogNormal Absolute/
      R.assign('log_mean', prob_distribution[2])
      R.assign('log_std', prob_distribution[3])
      R.eval 'samples <- qlnorm(q, log_mean, log_std)'
    else
      R.samples = []
    end
    return R.samples
  end

  def compute_sensitivities(
    response_file, design_file, out_dir, maxstring = 60, verbose = false
  )
    R.assign('y_file', response_file)
    R.assign('x_file', design_file)
    R.assign('out_dir', out_dir)
    R.assign('maxstring', maxstring)
    if verbose
      R.assign('verbose', 1)
    else
      R.assign('verbose', 0)
    end

    R.eval <<-RCODE
      table_name <- read.csv(x_file, header=TRUE, fill=TRUE,
                             strip.white=TRUE, stringsAsFactors=TRUE)

      # the following combines columns 1 and column 2 into one string for the
      # full name of the parameter for sensitivity analysis, truncates to first
      # maxstring char takes the transpose and converts back to a data frame

      b = data.matrix(t(substr(paste(table_name[[1]],
                                     table_name[[2]],
                                     sep = ": "), 1, maxstring)))
      # bframe = data.frame(t(b))
      library("sensitivity")
      load("#{out_dir}/Morris_design")
      # use check.names=FALSE to keep spaces in output names
      Table <- read.csv(y_file,header=TRUE, check.names=FALSE)
      Tablenames <- names(Table)
      Filenames <- gsub(' ', '.', names(Table))

      Y <- data.matrix(Table)

      outarray = list()

      pdf(sprintf("%s/Sensitivity_Plots.pdf", out_dir))

      for (i in 1:dim(Y)[2]) {
        # the following uses the data in Y and the morris info in design
        # to generate the output table in design
        tell(design, Y[, i])

        # extract the data as per the instructions in the sensitivity
        # package documentation
        mu <- apply(design$ee, 2, mean)
        mu.star <- apply(design$ee, 2, function(x) mean(abs(x)))
        sigma <- apply(design$ee, 2, sd)
        morrisout <- data.frame(mu, mu.star, sigma,
                                row.names=colnames(design$ee))
        outarray[[i]] = morrisout

        plot(design, main = Tablenames[i])

      tablename = sprintf("SA_wrt_%s.csv", Filenames[i])
        write.csv(morrisout, file=sprintf("%s/%s", out_dir, tablename),
                  row.names=b)

      }
      graphics.off() # use instead of dev.off() to avoid printout

      if (verbose > 0) {

        # print table mapping X1, X2, etc to variable names
        cat("\n Sensitivity Variable Table\n")
        print(data.frame(t(b), row.names=colnames(design$ee)))

        # print out the sensitivity tables
        cat("\nSensitivity Tables\n")
        # rename the tables using sensitivity table names instead
        names(outarray) <- names(Table)
        print(outarray)
      }
    RCODE
  end
end
