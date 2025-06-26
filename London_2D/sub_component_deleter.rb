# --- sub_component_deleter.rb (Version Corrigée - 26/06/2025) ---
require 'sketchup.rb'

begin
  require 'sketchup-dynamic-components/ruby/dcfunctions.rb'
rescue LoadError
end

module London2D
end

module London2D::SubComponentDeleter

  PLUGIN_DIR = File.dirname(__FILE__)
  PATH_TO_RESOURCES = File.join(PLUGIN_DIR, 'icons')

  class SubComponentDeleterTool
    
    def initialize
      @hovered_sub_component = nil
      @actual_parent_instance_context = nil
    end

    def activate
      puts "Outil 'Supprimer Sous-Composant' (Corrigé) activé."
      @model = Sketchup.active_model
      @hovered_sub_component = nil
      @actual_parent_instance_context = nil
      Sketchup.set_status_text("Survolez un sous-composant ou groupe et cliquez pour le supprimer.")
      @model.active_view.invalidate
    end
    
    def deactivate(view)
      view.invalidate if view
      Sketchup.set_status_text("")
    end

    # --- onMouseMove CORRIGÉ (Remonte le chemin pour trouver la cible) ---
    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      picked_path = ph.path_at(0)

      new_hover = nil
      @actual_parent_instance_context = nil

      # On s'assure d'avoir au moins un chemin (donc au moins une entité survolée)
      if picked_path && !picked_path.empty?
        # On parcourt le chemin de sélection à l'envers : de l'entité la plus profonde
        # vers la plus extérieure.
        picked_path.reverse_each do |current_entity|
          
          # NOTRE NOUVELLE CONDITION :
          # On cherche la première entité qui est une instance OU un groupe,
          # ET dont le parent est une définition (la marque d'un sous-objet).
          is_sub_object = (current_entity.is_a?(Sketchup::ComponentInstance) || current_entity.is_a?(Sketchup::Group)) &&
                          current_entity.parent.is_a?(Sketchup::ComponentDefinition)

          if is_sub_object
            # SUCCÈS ! On a trouvé notre VRAIE cible à supprimer.
            new_hover = current_entity
            
            # Maintenant, on doit trouver son INSTANCE parente pour la mise à jour DC.
            # On cherche cette cible dans le chemin d'origine pour trouver son index.
            target_index = picked_path.find_index(new_hover)
            
            # Le parent est l'élément juste avant dans le chemin.
            if target_index && target_index > 0
              parent_in_path = picked_path[target_index - 1]
              @actual_parent_instance_context = parent_in_path
            end

            # On a trouvé notre cible, on arrête de remonter le chemin.
            break 
          end
        end
      end
      
      # Le reste du code ne change pas
      if @hovered_sub_component != new_hover
        @hovered_sub_component = new_hover
        view.invalidate
      end
    end
    
    def draw(view)
      if @hovered_sub_component && @hovered_sub_component.valid?
        bounds = @hovered_sub_component.bounds
        view.drawing_color = "Red"
        view.line_width = 2; view.line_stipple = ""
        pts = (0..7).map { |i| bounds.corner(i) }
        view.draw(GL_LINE_LOOP, pts[0], pts[1], pts[3], pts[2])
        view.draw(GL_LINE_LOOP, pts[4], pts[5], pts[7], pts[6])
        view.draw(GL_LINES, pts[0], pts[4], pts[1], pts[5], 
                               pts[2], pts[6], pts[3], pts[7])
      end
    end

    def onLButtonDown(flags, x, y, view)
      if @hovered_sub_component && @hovered_sub_component.valid?
        component_to_delete = @hovered_sub_component
        
        parent_to_update_after_delete = @actual_parent_instance_context
        
        if parent_to_update_after_delete.nil?
          puts "AVERTISSEMENT: Contexte du parent immédiat non clairement identifié pour la mise à jour DC."
        end

        @model.start_operation("Supprimer Sous-Composant", true)
        begin
          definition_name = component_to_delete.definition.name
          puts "Suppression de '#{definition_name}'"
          component_to_delete.erase!
          
          if parent_to_update_after_delete && parent_to_update_after_delete.valid?
            puts "Mise à jour du parent direct '#{parent_to_update_after_delete.definition.name}'"
            force_dc_update(parent_to_update_after_delete)
          else
            puts "Aucun parent direct identifié pour la mise à jour DC après suppression."
          end
          
        rescue => e
          UI.messagebox("Erreur lors de la suppression :\n#{e.message}")
          @model.abort_operation
        else
          @model.commit_operation
          puts "Sous-composant '#{definition_name}' supprimé."
        end
        
        @hovered_sub_component = nil
        @actual_parent_instance_context = nil
        view.invalidate

      else
        puts "Aucun sous-composant valide survolé pour la suppression."
      end
    end
        
    def onCancel(reason); @model.select_tool(nil); end
    
    def force_dc_update(comp_instance)
      return unless comp_instance.attribute_dictionary('dynamic_attributes')
      puts " -> Mise à jour de '#{comp_instance.definition.name}'"
      if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class) && $dc_observers.get_latest_class
        $dc_observers.get_latest_class.redraw_with_undo(comp_instance)
      elsif defined?(Sketchup::DynamicComponents::Tools) && Sketchup::DynamicComponents::Tools.respond_to?(:update_attributes)
        Sketchup::DynamicComponents::Tools.update_attributes(comp_instance)
      end
      comp_instance.dynamic_attributes_updated if comp_instance.respond_to?(:dynamic_attributes_updated)
    end    
  end

  class << self
    def activate_deleter_tool
      Sketchup.active_model.select_tool(SubComponentDeleterTool.new)
    end
  end

  unless file_loaded?(__FILE__)
    cmd_delete = UI::Command.new("Supprimer Sous-Composant") { self.activate_deleter_tool }
    cmd_delete.small_icon = File.join(PATH_TO_RESOURCES, "delete_sub.png")
    cmd_delete.large_icon = File.join(PATH_TO_RESOURCES, "delete_sub.png")
    cmd_delete.tooltip = "Supprime le sous-composant survolé en un clic"
    toolbar = UI::Toolbar.new("London_2D"); toolbar.add_item(cmd_delete); toolbar.restore
    UI.menu("Plugins").add_item(cmd_delete)
    file_loaded(__FILE__)
  end
end