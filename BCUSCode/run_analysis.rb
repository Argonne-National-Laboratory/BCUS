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

# 1. Introduction
# This is the main function of analysis.

# 2. Call structure

# Use require to include functions from Ruby Library
require 'fileutils'
require 'csv'
require 'rubyXL'
require 'openstudio'

# Use require_relative to include ruby functions developed in the project
require_relative 'bcus_utils'
require_relative 'uncertain_parameters'
require_relative 'Stats'
require_relative 'run_osm'
require_relative 'process_simulation_sqls'
require_relative 'BC_runner'
require_relative 'graph_generator'
require_relative 'calibrated_osm'

# Module to perform main analysis functions
module RunAnalysis
  def self.run(run_type, options)
    # If the user didn't give the --osmName option, parse the rest of the input
    # arguments for a *.osm
    osm_file = File.absolute_path(
      parse_argv(
        options[:osmName], '.osm',
        'An OpenStudio OSM file must be indicated by the --osm option ' \
        'or giving a filename ending with .osm on the command line'
      )
    )

    # If the user didn't give the --epwName option, parse the rest of the input
    # arguments for a *.epw
    epw_file = File.absolute_path(
      parse_argv(
        options[:epwName], '.epw',
        'An .epw weather file must be indicated by the --epw option ' \
        'or giving a filename ending with .epw on the command line'
      )
    )

    # Assign common analysis settings
    out_spec_file = File.absolute_path(options[:outFile])
    randseed = Integer(options[:randseed])
    num_processes = Integer(options[:numProcesses])
    no_ep = options[:noEP]
    no_cleanup = options[:noCleanup]
    run_interactive = options[:interactive]
    verbose = options[:verbose]

    # If we are choosing noEP we also want to skip cleanup even if
    # it hasn't been selected
    no_cleanup = true if no_ep

    case run_type
    when 'UA'
      uq_repo_file = File.absolute_path(options[:uqRepo])
      num_lhd_runs = Integer(options[:numLHD])
      if verbose
        puts 'Running uncertainty analysis'
        puts "Using number of LHD samples  = #{num_lhd_runs}"
      end

    when 'SA'
      uq_repo_file = File.absolute_path(options[:uqRepo])
      morris_reps = Integer(options[:morrisR])
      morris_levels = Integer(options[:morrisL])
      if verbose
        puts 'Running sensitivity analysis'
        puts "Using morris repetitions = #{morris_reps}"
        puts "Using morris levels = #{morris_levels}"
      end

    when 'BC'
      priors_file = File.absolute_path(options[:priorsFile])
      utility_file = File.absolute_path(options[:utilityData])

      sim_name = options[:simFile]
      field_name = options[:fieldFile]
      posts_name = options[:postsFile]
      pvals_name = options[:pvalsFile]

      num_lhd_runs = Integer(options[:numLHD])
      num_mcmc = Integer(options[:numMCMC])
      num_out_vars = Integer(options[:numOutVars])
      num_w_vars = Integer(options[:numWVars])
      num_burnin = Integer(options[:numBurnin])

      if num_burnin >= num_mcmc
        puts 'Warning: numBurnin should be less than numMCMC. ' \
            "numBurnin has been reset to 0.\n"
        num_burnin = 0
      end

      no_plots = options[:noplots]
      no_run_cal = options[:noRunCal]

      if verbose
        puts 'Running Bayesian calibration'
        puts "Using number of LHD samples  = #{num_lhd_runs}"
      end
    end

    if verbose
      puts "Using number of parallel processes  = #{num_processes}"
      puts "Using random seed = #{randseed}"
      puts 'Not cleaning up interim files' if no_cleanup
    end

    # Acquire the path of the working directory that is the user's
    # project folder
    path = Dir.pwd
    model_dir = File.join(path, "#{run_type}_Model")
    run_dir = File.join(path, "#{run_type}_Simulations")
    out_dir = File.join(path, "#{run_type}_Output")
    Dir.mkdir(out_dir) unless Dir.exist?(out_dir)

    if run_type == 'BC'
      rlt_dir = File.join(path, "#{run_type}_Result")
      Dir.mkdir(rlt_dir) unless Dir.exist?(rlt_dir)
      
      sim_file = File.join(out_dir, sim_name)
      field_file = File.join(out_dir, field_name)
      posts_file = File.join(rlt_dir, posts_name)
      pvals_file = File.join(rlt_dir, pvals_name)
      graphs_dir = rlt_dir
    end

    # Extract out just the base filename from the OSM file as
    # the building name
    building_name = File.basename(osm_file, '.osm')

    # Check if .osm model exists and if so, load it
    model = read_osm_file(osm_file, verbose)

    # Check if .epw file exists
    check_file_exist(epw_file, 'EPW file', verbose)

    # Check if output file exist and if so, load it
    meters_table = read_table(
      out_spec_file, 'Output Seetings', 'Meters', verbose
    )

    # Check if UQ information file exists
    unless run_type == 'BC'
      check_file_exist(uq_repo_file, 'UQ repository file', verbose)
    else  
      check_file_exist(priors_file, 'Prior uncertainty info file', verbose)
    end

    wait_for_y('Running Interactively') if run_interactive

    ## Main process
    # Step 1: Generate uncertainty distributions
    if verbose
      puts "\nStep 1: Generating distribution of uncertainty parameters"
    end
    undertain_parameters = UncertainParameters.new
    unless run_type == 'BC'
      # Load UQ repository file
      uq_file = File.join(out_dir, "UQ_#{building_name}.csv")
      uq_table = read_table(uq_repo_file, 'UQ repository', 'UQ', verbose)
      # Remove the header rows
      2.times { uq_table.delete_at(0) }
      # Identify uncertainty parameters in the model
      undertain_parameters.find(model, uq_table, uq_file, verbose)
      # Check uncertainty information
      wait_for_y("Check the #{uq_file}") if run_interactive
    else
      # Load prior distribution file
      uq_table = read_prior_table(priors_file, verbose)
    end

    # Step 2: Generate design matrix for analysis
    if verbose
      puts "\nStep 2: Generating design Matrix and sample for analysis"
    end
    case run_type
    when 'UA'
      # Generate LHD sample
      stats = Stats.new
      params = {:n_runs => num_lhd_runs}
      stats.samples_generator(
        uq_file, 'LHD', params, out_dir, randseed, verbose
      )
      sample_file = File.join(out_dir, 'LHD_Sample.csv')
    when 'SA'
      # Generate Morris design sample
      stats = Stats.new
      params = {:morris_r => morris_reps, :morris_l => morris_levels}
      stats.samples_generator(
        uq_file, 'Morris', params, out_dir, randseed, verbose
      )
      sample_file = File.join(out_dir, 'Morris_Sample.csv')
    when 'BC'
      # Generate LHD sample
      stats = Stats.new
      params = {:n_runs => num_lhd_runs}
      stats.samples_generator(
        priors_file, 'LHD', params, out_dir, randseed, verbose
      )
      sample_file = File.join(out_dir, 'LHD_Sample.csv')
    end

    # Generate sample of parameters
    samples = CSV.read(sample_file, headers: false)
    samples.delete_at(0)
    num_runs = samples[0].length - 2
    param_names, param_types, param_values = extract_samples(samples)

    # Step 3: Create and run all OSM simulation files
    unless no_ep
      if verbose
        puts "Going to run #{num_runs} models. This could take a while"
      end
      # Generate sample of OSMs
      (0..(param_values.length - 1)).each do |k|
        # Reload the model explicitly to get the same starting point each time
        model = OpenStudio::Model::Model.load(osm_file).get
        undertain_parameters.apply(
          model, param_types, param_names, param_values[k]
        )

        # Add reporting meters
        add_reporting_meters_to_model(model, meters_table)

        # Add weather variable reporting to model and set its frequency
        add_output_variables_to_model(
          model, 'Site Outdoor Air Drybulb Temperature', 'Monthly'
        )
        add_output_variables_to_model(
          model, 'Site Ground Reflected Solar Radiation Rate per Area',
          'Monthly'
        )

        # Model saved to osm file
        model_sample_file = File.join(model_dir, "Sample#{k + 1}.osm")
        model.save(model_sample_file, true)

        # Add for thermostat algorithm
        uq_file_thermostat = File.join(
          out_dir, "UQ_#{building_name}_thermostat.csv"
        )
        undertain_parameters.apply_thermostat(
          model, uq_table, uq_file_thermostat, model_sample_file,
          param_types, param_values[k]
        )

        puts "Sample#{k + 1} is saved to the folder of Models" if verbose
      end

      puts "\nStep 3: Running #{num_runs} OSM simulations" if verbose
      wait_for_y if run_interactive

      runner = RunOSM.new
      runner.run_osm(model_dir, epw_file, run_dir, num_runs, num_processes)

    else
      if verbose
        puts "\nStep 3"
        puts '--noEP option selected, skipping creation of OpenStudio files ' \
          'and running of EnergyPlus'
        puts
      end

    end

    # Step 4: Read Simulation Results
    if verbose
      puts "\nStep 4: Post-processing and analyzing simulation results"
    end
    weather_flag = run_type.eql?('BC')
    OutPut.read(run_dir, out_spec_file, out_dir, weather_flag, verbose)

    # SA post-process
    if run_type == 'SA'
      max_chars = 60
      stats.compute_sensitivities(
        File.join(out_dir, 'Simulation_Results_Building_Total_Energy.csv'),
        uq_file, out_dir, max_chars, verbose
      )
    end

    # Delete intermediate files
    unless no_cleanup
      FileUtils.remove_dir(model_dir) if Dir.exist?(model_dir)
      to_be_cleaned =
        case run_type
        when 'UA', 'BC'
          ['Random_LHD_Samples.csv']
        when 'SA'
          [
            'Meter_Electricity_Facility.csv',
            'Meter_Gas_Facility.csv',
            'Morris_Design.csv',
            'Morris_Sample.csv',
            'Simulation_Results_Building_Total_Energy.csv'
          ]
        end
      to_be_cleaned.each do |file|
        clean_path = File.join(out_dir, file)
        File.delete(clean_path) if File.exist?(clean_path)
      end
    end

    if run_type == 'BC'

      # Step 5: Prepare calibration input files
      # y_sim, monthly drybuld and solar horizontal radiation,
      # calibration parameter samples...
      puts "\nStep5: Preparing calibration input files" if verbose

      y_elec_file = File.join(out_dir, 'Meter_Electricity_Facility.csv')
      y_gas_file = File.join(out_dir, 'Meter_Gas_Facility.csv')
      cal_sim_data_file = File.join(out_dir, 'cal_sim_data.txt')
      cal_field_data_file = File.join(out_dir, 'cal_field_data.txt')
      weather_file = File.join(out_dir, 'Monthly_Weather.csv')

      monthly_temp, monthly_solar = read_monthly_weather(weather_file)

      y_sim = get_y_sim(y_elec_file, y_gas_file)
      y_length = get_table_length(y_elec_file)

      cal_sim_data = get_cal_sim_data(
        y_sim, y_length, samples, monthly_temp, monthly_solar
      )
      write_to_file(cal_sim_data, cal_sim_data_file, verbose)

      cal_field_data = get_cal_field_data(
        utility_file, monthly_temp, monthly_solar, verbose
      )
      write_to_file(cal_field_data, cal_field_data_file, verbose)

      check_file_exist(sim_file, 'Computer Simulation File', verbose)
      check_file_exist(field_file, 'Utility Data File', verbose)

      # Step 6: Perform Bayesian calibration
      # Require the following files from parametric simulations
      # Parameters_Priors.csv
      # cal_field_data.txt
      # cal_sim_data.txt
      
      # LHD design is used now
      # Space filling design could be adopted later
      
      # cal_sim_data.txt: Computation data
      # In the order of: Monthly Energy Output;
      #                  Monthly Dry-bulb Temperature (C),
      #                  Monthly Global Horizontal Solar Radiation (W/M2)
      #                  Calibration Parameters
      
      # cal_field_data.txt: Observed data
      # In the order of: Monthly Energy Output;
      #                  Monthly Dry-bulb Temperature (C),
      #                  Monthly Global Horizontal Solar Radiation (W/M2)
    
      if verbose
        puts "\nStep 6: Performing Bayesian calibration of computer models"
        puts "Using number of output variables = #{num_out_vars}"
        puts "Using number of weather variables = #{num_w_vars}"
        puts "Using number of MCMC sample points = #{num_mcmc}"
        puts "Using number of burn-in sample points = #{num_burnin}"
        puts "Generating posterior values file = #{posts_name}"
        puts "Generating pvals file = #{pvals_name}"
      end

      # Perform Bayesian calibration
      code_path = ENV['BCUSCODE']
      puts "Using code path = #{code_path}\n\r" if verbose
      BCRunner.run_BC(
        code_path, priors_file, sim_file, field_file,
        num_out_vars, num_w_vars, num_mcmc,
        pvals_file, posts_file, randseed, verbose
      )

      puts 'Generating posterior distribution plots' if verbose
      # Could pass in graph file names too
      unless no_plots
        GraphGenerator.graphPosteriors(
          priors_file, pvals_file, num_burnin, graphs_dir, verbose
        )
      end

      # Run calibrated model
      unless no_run_cal
        puts "\nGenerate and run calibrated model" if verbose
        cal_model_dir = File.join(rlt_dir, 'Calibrated_Model')
        cal_osm = CalibratedOSM.new
        cal_osm.gen_and_sim(
          osm_file, epw_file, priors_file, posts_file,
          out_spec_file, cal_model_dir, verbose
        )
      end

    end

  end

end
