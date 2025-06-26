# --- dc_redraw_tool.rb ---
require 'sketchup.rb'

begin
  # Nécessaire pour Sketchup::DynamicComponents::Tools si utilisé
  require 'sketchup-dynamic-components/ruby/dcfunctions.rb' 
rescue LoadError
  # Pas critique si on utilise juste $dc_functions, mais bon à avoir pour Tools
end

module London2D
end

module London2D::DCRedrawTool

  PLUGIN_DIR = File.dirname(__FILE__)
  PATH_TO_RESOURCES = File.join(PLUGIN_DIR, 'icons')

  class << self
    def redraw_selected_dcs
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        UI.messagebox("Veuillez sélectionner un ou plusieurs composants dynamiques à redessiner.")
        return
      end

      dcs_to_redraw = selection.grep(Sketchup::ComponentInstance).select do |inst|
        inst.attribute_dictionary('dynamic_attributes')
      end

      if dcs_to_redraw.empty?
        UI.messagebox("Aucun composant dynamique trouvé dans la sélection.")
        return
      end

      model.start_operation("Redessiner Composants Dynamiques", true)
      
      puts "Redessin des composants dynamiques sélectionnés..."
      dcs_to_redraw.each do |dc_instance|
        force_one_dc_update(dc_instance)
      end
      
      model.commit_operation
      puts "#{dcs_to_redraw.count} composant(s) dynamique(s) redessiné(s)."
      model.active_view.refresh
    end

    # Fonction de mise à jour (similaire à celle que nous avons affinée)
    def force_one_dc_update(comp_instance)
      return unless comp_instance.attribute_dictionary('dynamic_attributes')
      
      puts " -> Redessin de '#{comp_instance.definition.name}'"
      
      # Priorité n°1 : Eneroth DC observers (méthode la plus fiable)
      if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class) && $dc_observers.get_latest_class
        puts "    -> via Eneroth DC Observers"
        $dc_observers.get_latest_class.redraw_with_undo(comp_instance)
      # Priorité n°2 : Votre méthode qui fonctionne, Tools.update_attributes
      elsif defined?(Sketchup::DynamicComponents::Tools) && Sketchup::DynamicComponents::Tools.respond_to?(:update_attributes)
        puts "    -> via Tools.update_attributes"
        Sketchup::DynamicComponents::Tools.update_attributes(comp_instance)
      # Priorité n°3 : $dc_functions.redraw (un peu moins fiable mais standard)
      elsif defined?($dc_functions) && $dc_functions.respond_to?(:redraw)
        puts "    -> via $dc_functions.redraw"
        $dc_functions.redraw(comp_instance)
      end
      
      comp_instance.dynamic_attributes_updated if comp_instance.respond_to?(:dynamic_attributes_updated)
    end
  end # fin de class << self

  unless file_loaded?(__FILE__)
    cmd_redraw = UI::Command.new("Redessiner DC Sélectionné(s)") { self.redraw_selected_dcs }
    cmd_redraw.small_icon = File.join(PATH_TO_RESOURCES, "redraw.png")
    cmd_redraw.large_icon = File.join(PATH_TO_RESOURCES, "redraw.png")
    cmd_redraw.tooltip = "Redessine le(s) composant(s) dynamique(s) sélectionné(s)"
    
    toolbar = UI::Toolbar.new("London_2D") # Réutilise la barre existante
    toolbar.add_item(cmd_redraw)
    toolbar.restore
    
    UI.menu("Plugins").add_item(cmd_redraw) # Optionnel: ajouter au menu
    
    file_loaded(__FILE__)
  end

end