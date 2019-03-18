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
- Created on Feb 27, 2015 by Yuming Sun and Matt Riddle from Argonne National Laboratory


1. Introduction
This is the main code used for running morris method

=end


#===============================================================%
#     author: Yuming Sun and Matt Riddle										    %
#     date: Feb 27, 2015										                    %
#===============================================================%

# Main code used for running morris method
# Updated code to pass morris_R, morris_levels, and randseed from calling routine 12-Sep-2015 RTM

require_relative 'rinruby'
require 'csv'

class Morris

  # Compute the sensitivities for the given model via the Morris method
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

  def design_matrix(file_path, file_name, morris_R, morris_levels, randseed=0)
    puts "Randseed = #{randseed}" if randseed !=0
    table = CSV.read("#{file_name}")
    n_parameters = table.count-1 # the first row is the header
    R.assign('randseed', randseed) # set the random seed.
    R.assign('n', n_parameters)
    R.assign('mR', morris_R)

    R.eval('library("sensitivity")')
    R.eval('if (randseed!=0){set.seed(randseed)} else {set.seed(NULL)}')

    R.eval <<EOF
            design <- morris(NULL, n, mR, binf=0.05, bsup=0.95, scale=FALSE, design = list(type = "oat", levels = #{morris_levels}, grid.jump = 4))
EOF
    R.eval('X <- design$X')
    R.eval('save (design, file="Morris_design")')

    design_matrix = R.X
    row_index = 0
    CSV.open("#{file_path}/Morris_0_1_Design.csv", 'wb')
    CSV.open("#{file_path}/Morris_0_1_Design.csv", 'a+') do |csv|
      while row_index <= design_matrix.row_count
        csv<< design_matrix.row(row_index).to_a
        row_index +=1
      end
    end

# CDF transform
    row_index = 0
    CSV.open("#{file_path}/Morris_CDF_Tran_Design.csv", 'wb')
    CSV.open("#{file_path}/Morris_CDF_Tran_Design.csv", 'a+') do |csv|
      header = table[0].to_a[0, 2]
      for sample_index in 1..design_matrix.row_count
        header << "Run #{sample_index}"
      end
      csv << header

      CSV.foreach("#{file_name}", headers: true, converters: :numeric) do |parameter|
        prob_distribution = [parameter['Parameter Base Value'],
                             parameter['Distribution'],
                             parameter['Mean or Mode'],
                             parameter['Std Dev'],
                             parameter['Min'],
                             parameter['Max']]
        q = design_matrix.transpose.row(row_index).to_a
        csv << table[row_index+1].to_a[0, 2] + cdf_inverse(q, prob_distribution)
        row_index +=1
      end
    end
  end

  def cdf_inverse(random_num, prob_distribution)
    R.assign('q', random_num)
    case prob_distribution[1]
      when /Normal Absolute/
        R.assign('mean', prob_distribution[2])
        R.assign('std', prob_distribution[3])
        R.eval 'samples<- qnorm(q,mean,std)'

      when /Normal Relative/
        R.assign('mean', prob_distribution[2]*prob_distribution[0])
        R.assign('std', prob_distribution[3]*prob_distribution[0])
        R.eval 'samples<- qnorm(q,mean,std)'

      when /Uniform Absolute/
        R.assign('min', prob_distribution[4])
        R.assign('max', prob_distribution[5])
        R.eval 'samples<- qunif(q,min,max)'

      when /Uniform Relative/
        R.assign('min', prob_distribution[4]*prob_distribution[0])
        R.assign('max', prob_distribution[5]*prob_distribution[0])
        R.eval 'samples<- qunif(q,min,max)'

      when /Triangle Absolute/
        R.assign('min', prob_distribution[4])
        R.assign('max', prob_distribution[5])
        R.assign('mode', prob_distribution[2])
        R.eval 'library("triangle")'
        R.eval 'samples<- qtriangle(q,min,max,mode)'

      when /Triangle Relative/
        R.assign('min', prob_distribution[4]*prob_distribution[0])
        R.assign('max', prob_distribution[5]*prob_distribution[0])
        R.assign('mode', prob_distribution[2]*prob_distribution[0])
        R.eval 'library("triangle")'
        R.eval 'samples<- qtriangle(q,min,max,mode)'

      when /LogNormal Absolute/
        R.assign('log_mean', prob_distribution[2])
        R.assign('log_std', prob_distribution[3])
        R.eval 'samples<- qlognorm(q,log_mean,log_std)'

      else
        R.samples = []
    end
    return R.samples
  end

  def compute_sensitivities(model_response_file, file_path, file_name)
    R.assign('y_file', model_response_file)
    R.assign('file_path', file_path)
    R.assign('file_name', file_name)
    R.eval <<EOF
table_name<-read.csv(file_name,header = TRUE,fill = TRUE, strip.white = TRUE,stringsAsFactors=TRUE)
a=table_name[1]
b=t(a)
library("sensitivity")
load("Morris_design")
Table <- read.csv(y_file,header=TRUE)
Y <- data.matrix(Table)
pdf(sprintf("%s/Sensitivity_Plots.pdf",file_path))
for (i in 1:dim(Y)[2]){
tell(design,Y[, i])
write.csv(print(design), file = sprintf("%s/SA_wrt_%s.csv", file_path, names(Table)[i]),row.names = b)
plot(design, main = names(Table)[i])
}
dev.off()
EOF

  end
end


