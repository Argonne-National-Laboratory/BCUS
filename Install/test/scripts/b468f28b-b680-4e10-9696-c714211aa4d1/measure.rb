# Author: Julien Marrec
# email: julien.marrec@gmail.com

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# start the measure
class EnableDetailedOutputForEachNodeInALoop < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Enable Detailed Output for Each Node in a Loop"
  end

  # human readable description
  def description
    return "Given a plant loop and a number of parameters including which variables to output, this adds some Output:Variable for each node of the plantLoop or airLoop.

The user is also asked to specify whether or not he wants to include the demand nodes (zones). "
  end

  # human readable description of modeling approach
  def modeler_description
    return "The user is asked to provided the following parameters:
- A plantLoop or airLoop from the model (dropdown)
- A boolean to include or exclude demand nodes
- Which variable they want to output for each node:
    * System Node Temperature
    * System Node Setpoint Temperature
    * System Node Mass Flow Rate 
    * etc."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #####################     Loop to apply it to    #####################

    # make a choice argument for model objects
    # We will add both the plantLoops and the airLoopHVACs in there
    # Separated by blanks and '------ XXX Loop ------'

    loop_handles = OpenStudio::StringVector.new
    loop_display_names = OpenStudio::StringVector.new


    # ====================     airLoopHVAC   ====================


    #putting model object and names into hash
    loop_handles_args = model.getAirLoopHVACs
    loop_handles_args_hash = {}
    loop_handles_args.each do |loop_handles_arg|
      loop_handles_args_hash[loop_handles_arg.name.to_s] = loop_handles_arg
    end

    # Section title
    loop_handles << OpenStudio::toUUID("").to_s
    loop_display_names << "------ airLoopHVACs -------"

    #looping through sorted hash of model objects
    loop_handles_args_hash.sort.map do |key,value|
      loop_handles << value.handle.to_s
      loop_display_names << key
    end

    # Seperator: a blank
    loop_handles << OpenStudio::toUUID("").to_s
    loop_display_names << ""



    # ====================     PlantLoop   ====================

    #putting model object and names into hash
    loop_handles_args = model.getPlantLoops
    loop_handles_args_hash = {}
    loop_handles_args.each do |loop_handles_arg|
      loop_handles_args_hash[loop_handles_arg.name.to_s] = loop_handles_arg
    end

    # Section title
    loop_handles << OpenStudio::toUUID("").to_s
    loop_display_names << "------ plantLoops -------"

    #looping through sorted hash of model objects
    loop_handles_args_hash.sort.map do |key,value|
      loop_handles << value.handle.to_s
      loop_display_names << key
    end


    #make a choice argument for the loop
    loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("loop", loop_handles, loop_display_names, true)
    loop.setDisplayName("Select the plantLoop for which you want to report the node variables")
    loop.setDescription("You can select a plantLoop or an airLoopHVAC.")
    args << loop


    include_demand_nodes = OpenStudio::Ruleset::OSArgument::makeBoolArgument("include_demand_nodes",true)
    include_demand_nodes.setDisplayName("Include Demand Side nodes in the output?")
    include_demand_nodes.setDefaultValue("false")
    args << include_demand_nodes

    chs = OpenStudio::StringVector.new
    chs << "Detailed"
    chs << "Timestep"
    chs << "Hourly"
    chs << "Daily"
    chs << "Monthly"
    #chs << "RunPeriod"
    reporting_frequency = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('reporting_frequency', chs, true)
    reporting_frequency.setDisplayName("<h3>Select a Reporting Frequency?</h3>")
    reporting_frequency.setDefaultValue("Timestep")
    args << reporting_frequency

    # Add a delimiter for clarify
    delimiter = OpenStudio::Ruleset::OSArgument::makeStringArgument('delimiter', false)
    delimiter.setDisplayName("<hr><h3>Select the reporting variables you want to include</h3>")
    delimiter.setDefaultValue("-----------------------------------------------------------------")
    args << delimiter


    # Reporting variables
    varhash =  {'System Node Temperature' => true,
                'System Node Setpoint Temperature' => true,
                'System Node Mass Flow Rate' => true,

                'System Node Humidity Ratio' => false,
                'System Node Setpoint High Temperature' => false,
                'System Node Setpoint Low Temperature' => false,
                'System Node Setpoint Humidity Ratio' => false,
                'System Node Setpoint Minimum Humidity Ratio' => false,
                'System Node Setpoint Maximum Humidity Ratio' => false,
                'System Node Relative Humidity' => false,
                'System Node Pressure' => false,
                'System Node Standard Density Volume Flow Rate' => false,
                'System Node Current Density Volume Flow Rate' => false,
                'System Node Current Density' => false,
                'System Node Enthalpy' => false,
                'System Node Wetbulb Temperature' => false,
                'System Node Dewpoint Temperature' => false,
                'System Node Quality' => false,
                'System Node Height' => false }

    varhash.each do |k, v|

      newarg = OpenStudio::Ruleset::OSArgument::makeBoolArgument(k, true)
      newarg.setDisplayName(k)
      newarg.setDefaultValue(v)
      args << newarg

    end


    return args
  end


  def addNodeNamestoArray(model_objects, node_names)
    model_objects.each do |model_object|
      unless model_object.to_Node.empty?
        model_node = model_object.to_Node.get
        # A node has necessarily a name
        node_names << model_node.name.get
      end
    end

    return node_names
  end


  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end


    # get the Loop
    loop = runner.getOptionalWorkspaceObjectChoiceValue("loop", user_arguments, model)

    # check the zone for reasonableness
    if loop.empty?
      handle = runner.getStringArgumentValue("loop",user_arguments)
      if handle.empty?
        runner.registerError("No plantLoop or airLoop was selected.")
      else
        runner.registerError("The selected loop type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      # If its an airLoopHVAC
      if not loop.get.to_AirLoopHVAC.empty?
        #If everything's alright, get the actual Thermal Zone object from the handle
        loop = loop.get.to_AirLoopHVAC.get
        is_airLoopHVAC = true
        runner.registerInfo("Found the airLoopHVAC surface #{loop.name}")
      elsif not loop.get.to_PlantLoop.empty?
        loop = loop.get.to_PlantLoop.get
        is_airLoopHVAC = false
        runner.registerInfo("Found the plantLoop #{loop.name}")
      else
        runner.registerError("Script Error - argument not showing up as plantLoop or airLoopHVAC. Did you select the delimiter?")
        return false
      end
    end


    include_demand_nodes = runner.getBoolArgumentValue("include_demand_nodes",user_arguments)

    if include_demand_nodes
      runner.registerInfo("Demand Nodes will be included. This can lead to many nodes.")
    end

    reporting_frequency = runner.getStringArgumentValue("reporting_frequency",user_arguments)


    # Retrieve variables
    varhash =  {'System Node Temperature' => true,
                'System Node Setpoint Temperature' => true,
                'System Node Mass Flow Rate' => true,
                'System Node Humidity Ratio' => false,
                'System Node Setpoint High Temperature' => false,
                'System Node Setpoint Low Temperature' => false,
                'System Node Setpoint Humidity Ratio' => false,
                'System Node Setpoint Minimum Humidity Ratio' => false,
                'System Node Setpoint Maximum Humidity Ratio' => false,
                'System Node Relative Humidity' => false,
                'System Node Pressure' => false,
                'System Node Standard Density Volume Flow Rate' => false,
                'System Node Current Density Volume Flow Rate' => false,
                'System Node Current Density' => false,
                'System Node Enthalpy' => false,
                'System Node Wetbulb Temperature' => false,
                'System Node Dewpoint Temperature' => false,
                'System Node Quality' => false,
                'System Node Height' => false }

    variable_names = []
    varhash.each do |k, v|
      temp_var = runner.getBoolArgumentValue(k,user_arguments)
      if temp_var
        variable_names << k
      end
    end

    if variable_names.size == 0
      runner.registerError("You need to select at least one output variable")
      return false
    end

    # Report initial condition of model
    init_number_variables = model.getOutputVariables.size
    runner.registerInitialCondition("The model started out with #{init_number_variables} output variables")

    runner.registerInfo("<b style='color: #00529B;background-color:#BDE5F8;'>#{variable_names.size} variables have been requested:</b>\n* #{variable_names.join("\n* ")}\n")
    puts "Here are the variable you have selected:"
    puts variable_names



    # Get 'em Nodes!
    # Idd type for Nodes
    node_type = OpenStudio::Model::Node::iddObjectType

    # Create an array to store the node names
    node_names = []

    # Add the Supply objects
    supply_objects = loop.supplyComponents(node_type)
    node_names = addNodeNamestoArray(supply_objects, node_names)

    # If an AirLoop, Also add the Outside Air System Nodes
    if is_airLoopHVAC
      oa_objects = loop.oaComponents(node_type)
      node_names = addNodeNamestoArray(oa_objects, node_names)
    end

    # If you want to include the Demand side nodes
    if include_demand_nodes
      # Get all the demand components of type node
      dm_objects = loop.demandComponents(node_type)
      node_names = addNodeNamestoArray(dm_objects, node_names)
    end

    # Make it unique, just in case (shouldn't be a problem at all)
    node_names.uniq!

    num_var_to_create = variable_names.size * node_names.size
    runner.registerInfo("<b style='color: #00529B;background-color:#BDE5F8;'>We found #{node_names.size} corresponding Nodes.</b>\n")
    runner.registerInfo("<b>==> #{node_names.size} nodes x #{variable_names.size} variables = <span style='color:#862d2d'>#{num_var_to_create} variables to create.</span></b>\n")


    #Add the output variables
    node_names.each { |node_name|
      runner.registerInfo("Enabling variables for Node #{node_name}")
      puts "\n\n==================== Node: #{node_name} ===================="
      variable_names.each { |variable_name|
        outputVariable = OpenStudio::Model::OutputVariable.new(variable_name,model)
        outputVariable.setReportingFrequency(reporting_frequency)
        outputVariable.setKeyValue(node_name)
        puts outputVariable
        puts "\n"
      }
    }


    num_var_created = model.getOutputVariables.size - init_number_variables
    if num_var_created = num_var_to_create
      runner.registerFinalCondition("<b style='color: #4F8A10;background-color:#DFF2BF;'>The model has now #{model.getOutputVariables.size} output variables.</b> #{num_var_created} variables were added.\n")
    else
      runner.registerFinalCondition("The model has now #{model.getOutputVariables.size} output variables")
      runner.registerWarning("<b style='color: #9F6000;background-color:#FEEFB3;'>#{num_var_to_create} should have been created, but only #{num_var_created} were actually created.</b>")
    end

    # Report final condition of model


    return true

  end
  
end

# register the measure to be used by the application
EnableDetailedOutputForEachNodeInALoop.new.registerWithApplication
