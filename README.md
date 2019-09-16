# BCUS: Bayesian Calibration, Uncertainty, and Sensitivity
BCUS: Bayesian Calibration, Uncertainty, and Sensitivity is a cross platform set of Ruby and R scripts to support sensitivity analysis, uncertainty analysis, and Bayesian calibration of OpenStudio energy models.

Tutorials explaining installation and use of BCUS are found within the tutorials directory.

The software has been developed in Windows 10 and has been tested on OS-X 10.14.


## Installation

#### BCUS has the following dependencies

* OpenStudio (>=2.7.0) with Ruby 2.2.4 bindings and EnergyPlus
* Ruby 2.2.4
* Ruby Gems: rubyXL (require nokogiri v1.9.1 or older), rinruby, parallel, ruby-progressbar
* R (>=3.1.0)
* R packages: sensitivity, ggplot2, lhs, car, triangle, gridextra 

* BCUS makes use of .xlsx spreadsheets.  While these can be read and written using OpenOffice or LibreOffice, some of the 

#### OpenStudio Install

Download and install the latest OpenStudio from https://www.openstudio.net/downloads.

*To make it easier to reference/access the OpenStudio Path, some users like to install OpenStudio in 
a root directory such as C:\openstudio-2.7.0.*

#### Ruby Install

* Install Ruby 2.2.4

	For windows users it is recommended to use RubyInstaller obtained from http://rubyinstaller.org/downloads/.
	
	For OSX and Linux users it is recommended that you use the ruby version manager (rvm) or rbenv: https://github.com/rbenv/rbenv.

* Intall the required ruby gems with the command:   
	`gem install nokogiri -v 1.9.1`  
	`gem install rubyXL`  
	`gem install rinruby`  
	`gem install parallel`  
	`gem install ruby-progressbar`

* Create a textfile called OpenStudio.rb in the Ruby lib/ruby/site_ruby directory with the contents:

	`require 'OPENSTUDIO_ROOT_DIR\Ruby\openstudio.rb'`
	
	where you replace OPENSTUDIO_ROOT_DIR with the root directory for your OpenStudio installation, e.g. something like "C:\openstudio-2.7.0".

#### R Install

You can obtain an R install from the Comprehensive R Archive Network (http://cran.r-project.org), but for higher performance, you may prefer to install Microsoft R Open with MKL extensions (https://mran.revolutionanalytics.com/download/).


#### BCUS Installation

* Copy the BCUSCode directory to your location of choice and set the environmental variable "BCUSCODE" to that directory.
* Add the same directory to your RUBYPATH.

    For example, on a Windows system where BCUSCode is in C:\BCUS\BCUSCode you would set the following:  

    `set BCUSCODE=C:\BCUS\BCUSCode`  
    `set RUBYPATH=C:\BCUS\BCUSCode;%RUBYPATH%`  
	`setx BCUSCODE "C:\BCUS\BCUSCode"`  
	`setx RUBYPATH "C:\BCUS\BCUSCode;%RUBYPATH%"`  
	
    *NOTE: In windows, to permanently set the environmental variables you also need to use the setx command.*

    On a MacOS system you would set the following:

    `export BCUSCODE=C:\BCUS\BCUSCode`  
    `export RUBYPATH=C:\BCUS\BCUSCode:$RUBYPATH` 

    *To make the setting permanently, add the above statements to the `~/.bash_profile` file.*

* Install R packages  
Install the R packages sensitivity, ggplot2, lhs, car, triangle, gridextra.


### Testing the installation

You can do a basic test of the installation by downloading the Install directory, opening a command line, and running the test.bat or test.sh file.

This script will test Uncertainty Analysis, Sensitivity Analysis, and then Bayesian Calibration scripts.  

* The Uncertainty Analysis test will generate and run 3 models
* The Sensitivity Analysis test will generate and run 6 models
* The Bayesian Calibration test will generate and run 6 models


## Documentation

Instructions on how to use/run/modify are in the Tutorials directory.


## Usage

Use the example directory as a base for your project. Modify the files as discussed in the tutorials.


## Caveats and Todos


## Contributing

1. Fork it (https://github.com/Argonne-BEDTR/BCUS/fork).
2. Create your feature branch (`git checkout -b my-new-feature`).
3. Commit your changes (`git commit -am 'Add some feature'`).
4. Push to the branch (`git push origin my-new-feature`).
5. Create a new Pull Request.
6. Wait a while until we find time to review the Pull Request.
