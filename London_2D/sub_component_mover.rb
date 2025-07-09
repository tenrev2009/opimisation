# sub_component_mover.rb
# Version finale qui utilise un déplacement géométrique simple (transform!)

require 'sketchup.rb'
require 'extensions.rb'

module London_2D
  PLUGIN_ID = 'London_2D.quick_move_sub_transform' # ID final

  unless file_loaded?(PLUGIN_ID)
    class QuickMoveSubTool
      # Les méthodes d'initialisation, de détection et de dessin sont stables
      def initialize
        @hovered_instance = nil
        @hovered_transformation = nil
      end

      def activate
        Sketchup.set_status_text('Clic: Monter | Ctrl+Clic: Descendre')
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

      # --- La méthode de clic, revenue à la logique la plus simple et directe ---
      def onLButtonDown(flags, x, y, view)
        return unless @hovered_instance && @hovered_instance.valid?

        is_moving_down = (flags & MK_CONTROL) != 0
        move_distance = is_moving_down ? -2.5.cm : 2.5.cm

        model = view.model
        model.start_operation('Move Component Geometrically', true)
        
        begin
          # 1. Créer un vecteur de déplacement sur l'axe Z.
          move_vector = Geom::Vector3d.new(0, 0, move_distance)
          
          # 2. Créer une transformation à partir de ce vecteur.
          transformation = Geom::Transformation.translation(move_vector)
          
          # 3. Appliquer la transformation géométrique directement à l'instance.
          @hovered_instance.transform!(transformation)
          
          # 4. PAS D'APPEL à une fonction de redessin DC.
          
          model.commit_operation
        rescue => e
          puts "Erreur lors de la transformation: #{e.message}"
          model.abort_operation
        end
        
        # On met à jour la transformation stockée pour que le contour rouge suive l'objet
        if @hovered_instance && @hovered_instance.valid?
            ph = view.pick_helper
            ph.init(@hovered_instance.model_path)
            @hovered_transformation = ph.transformation
        end
        view.invalidate
      end
    end

    # --- Barre d'outils ---
    cmd = UI::Command.new("Déplacement Géométrique") { Sketchup.active_model.select_tool(QuickMoveSubTool.new) }
    cmd.tooltip = "Déplacer un sous-composant en Z (Clic/Ctrl+Clic)"
    cmd.status_bar_text = "Clic pour monter, Ctrl+Clic pour descendre."
    icon_folder = File.join(File.dirname(__FILE__), 'icons')
    icon_path = File.join(icon_folder, 'move_sub.png')
    if File.exist?(icon_path); cmd.small_icon = icon_path; cmd.large_icon = icon_path; end
    toolbar = UI::Toolbar.new("London_2D"); toolbar.add_item(cmd); toolbar.show
    file_loaded(PLUGIN_ID)
  end
end