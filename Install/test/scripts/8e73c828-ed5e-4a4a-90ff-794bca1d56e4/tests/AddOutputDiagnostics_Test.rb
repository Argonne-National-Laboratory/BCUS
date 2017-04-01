require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'minitest/autorun'

class AddOutputDiagnostics_Test < MiniTest::Test
  
  def test_AddOutputDiagnostics
     
    # create an instance of the measure
    measure = AddOutputDiagnostics.new
    
    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new
    
    # make an empty model
    model = OpenStudio::Model::Model.new

    # forward translate OpenStudio Model to EnergyPlus Workspace
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(workspace)
    assert_equal(1, arguments.size)
    assert_equal("outputDiagnostic", arguments[0].name)
       
    # set argument values to good values and run the measure on the workspace
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    outputDiagnostic = arguments[0].clone
    assert(outputDiagnostic.setValue("DisplayExtraWarnings"))
    argument_map["outputDiagnostic"] = outputDiagnostic

    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.info.size == 1)
    
  end

end