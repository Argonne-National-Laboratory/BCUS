# Author: Julien Marrec
# email: julien.marrec@gmail.com

require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'
require 'json'

class EnableDetailedOutputForEachNodeInALoopTest < MiniTest::Unit::TestCase

  def setup
    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/2plantloops_oneairloop_named_nodes.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    return model
  end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = EnableDetailedOutputForEachNodeInALoop.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    argnames = ["loop",
                "include_demand_nodes",
                "reporting_frequency",
                "delimiter",
                "System Node Temperature",
                "System Node Setpoint Temperature",
                "System Node Mass Flow Rate",
                "System Node Humidity Ratio",
                "System Node Setpoint High Temperature",
                "System Node Setpoint Low Temperature",
                "System Node Setpoint Humidity Ratio",
                "System Node Setpoint Minimum Humidity Ratio",
                "System Node Setpoint Maximum Humidity Ratio",
                "System Node Relative Humidity",
                "System Node Pressure",
                "System Node Standard Density Volume Flow Rate",
                "System Node Current Density Volume Flow Rate",
                "System Node Current Density",
                "System Node Enthalpy",
                "System Node Wetbulb Temperature",
                "System Node Dewpoint Temperature",
                "System Node Quality",
                "System Node Height"]

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(argnames.size, arguments.size)


    argnames.each_with_index do |name, i|
      assert_equal(name, arguments[i].name)
    end
  end

  def run_one_json_test(args_hash, output)

    # create an instance of the measure
    measure = EnableDetailedOutputForEachNodeInALoop.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    model = setup()

    init_number_variables = model.getOutputVariables.size

    puts "Initial number of output variables: #{init_number_variables}"

    puts args_hash

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        puts "Argument name: #{arg.name}"
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end


    puts "ARGUMENT MAP"
    puts argument_map

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal(output["result"], result.value.valueName)

    # If there's a need to check the number of variables created, do so
    if output.has_key?("num_var_created")
      num_var_created =  model.getOutputVariables.size - init_number_variables
      assert_equal(output["num_var_created"], num_var_created)
    end
    puts "Number of info: #{result.info.size}"
    puts "Number of warnings: #{result.warnings.size}"

  end

  def test_all_cases

    tests_json = {}
    File.open(File.dirname(__FILE__) + '/test_cases.json', 'r:UTF-8') do |f|
      tests_json = JSON.load(f)
    end

    puts "########################################"
    puts "Test cases to run:"
    puts tests_json.keys()
    puts "########################################\n\n"


    tests_json.each do |k, v|
      outcome = v['output']['result']
      puts "===================================================="
      puts "Running test #{k} with expected outcome = #{outcome}"
      run_one_json_test(v['args_hash'], v['output'])
      puts "\n\n\n"
    end

  end

end
