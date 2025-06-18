require 'sketchup.rb'

module London2D
  plugin_root = File.join(__dir__, 'London_2D')

  require File.join(plugin_root, "shelf_calculator", "shelf_calculator.rb")
  require File.join(plugin_root, "shelf_report", "shelf_report.rb")
  require File.join(plugin_root, "dynamic_3d", "inject_3d.rb") # Ajoute ceci pour charger le script 3D

  file_loaded(__FILE__)
end


