# sub_component_duplicator.rb
# Version corrigée pour l'erreur d'argument dans la méthode de dessin.

require 'sketchup.rb'
require 'extensions.rb'

module London_2D
  PLUGIN_ID = 'London_2D.quick_duplicate_sub' 

  unless file_loaded?(PLUGIN_ID)
    class QuickDuplicateSubTool
      def initialize
        @hovered_instance = nil
        @hovered_transformation = nil
      end

      def activate
        Sketchup.set_status_text('Cliquez pour dupliquer le sous-composant au même niveau.')
      end

      def deactivate(view)
        Sketchup.set_status_text('')
        view.invalidate if view
      end

      def onMouseMove(flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y, 10)
        path = ph.path_at(0)
        inst = nil; inst_path_index = -1
        if path
          path.reverse_each.with_index do |entity, i|
            if (entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)) && entity.parent.is_a?(Sketchup::ComponentDefinition)
              if (entity.definition.name || '') =~ /tab|bac/i
                inst = entity; inst_path_index = path.length - 1 - i; break
              end
            end
          end
        end
        if inst && inst.valid?
          if @hovered_instance != inst
            @hovered_instance = inst
            @hovered_transformation = ph.transformation_at(inst_path_index)
          end
        else
          @hovered_instance = nil
        end
        view.invalidate
      end

      # --- Méthode DRAW corrigée ---
      # On revient à la logique stable qui utilise la transformation stockée
      def draw(view)
        return unless @hovered_instance && @hovered_instance.valid? && @hovered_transformation
        
        view.line_width = 2; view.drawing_color = 'blue'
        
        local_bounds = @hovered_instance.definition.bounds
        corners = (0..7).map { |i| local_bounds.corner(i) }
        world_corners = corners.map { |pt| pt.transform(@hovered_transformation) }
        
        view.draw(GL_LINE_LOOP, world_corners[0], world_corners[1], world_corners[3], world_corners[2])
        view.draw(GL_LINE_LOOP, world_corners[4], world_corners[5], world_corners[7], world_corners[6])
        view.draw(GL_LINES, world_corners[0], world_corners[4], world_corners[1], world_corners[5], world_corners[2], world_corners[6], world_corners[3], world_corners[7])
      end

      def onLButtonDown(flags, x, y, view)
        return unless @hovered_instance && @hovered_instance.valid?

        # On vérifie si l'utilisateur est en train d'éditer le parent
        # pour éviter l'erreur de "définition récursive".
        if Sketchup.active_model.active_path && Sketchup.active_model.active_path.include?(@hovered_instance)
           UI.messagebox("Veuillez sortir du mode d'édition du composant avant de le dupliquer.")
           return
        end

        model = view.model
        model.start_operation('Duplicate Sibling Sub-Component', true)
        
        begin
          parent_entities = @hovered_instance.parent.entities
          move_vector = Geom::Vector3d.new(0, 0, 32.5.cm)
          move_transformation = Geom::Transformation.translation(move_vector)
          
          new_instance = parent_entities.add_instance(
            @hovered_instance.definition, 
            @hovered_instance.transformation
          )
          
          new_instance.make_unique
          new_instance.transform!(move_transformation)
          
          model.commit_operation
        rescue => e
          puts "Erreur lors de la duplication: #{e.message}"
          UI.messagebox("Erreur lors de la duplication: #{e.message}")
          model.abort_operation
        end
        
        view.invalidate
      end
    end

    # --- Barre d'outils ---
    cmd = UI::Command.new("Duplication Hiérarchique") { Sketchup.active_model.select_tool(QuickDuplicateSubTool.new) }
    cmd.tooltip = "Dupliquer un sous-composant au même niveau"
    cmd.status_bar_text = "Cliquez pour créer une copie unique du sous-composant vers le haut."
    icon_folder = File.join(File.dirname(__FILE__), 'icons')
    icon_path = File.join(icon_folder, 'duplicate_sub.png')
    if File.exist?(icon_path); cmd.small_icon = icon_path; cmd.large_icon = icon_path; end
    toolbar = UI::Toolbar.new("London_2D"); toolbar.add_item(cmd); toolbar.show
    file_loaded(PLUGIN_ID)
  end
end