# Quick Duplicate Sub-Components Plugin for SketchUp
# sub_component_duplicator.rb
# Version 10.3 – idem 10.0 + redraw DC automatique après copie

require 'sketchup.rb'
require 'extensions.rb'

module London_2D
  PLUGIN_ID   = 'London_2D.quick_duplicate_sub'
  PARENT_NAME = 'Rayonnage'
  CHILD_REGEX = /bac|tab/i

  unless file_loaded?(PLUGIN_ID)
    class QuickDuplicateSubTool
      def initialize
        @hovered_instance       = nil
        @hovered_transformation = nil
        @parent_inst            = nil
        @last_new_inst          = nil
      end

      def activate
        Sketchup.set_status_text('Outil : dupliquer un bac/tab direct de Rayonnage.')
      end

      def deactivate(view)
        Sketchup.set_status_text('')
        view.invalidate if view
      end

      def onMouseMove(flags, x, y, view)
        ph   = view.pick_helper
        ph.do_pick(x, y, 10)
        path = ph.path_at(0) || []

        parent_idx = path.index { |e|
          e.is_a?(Sketchup::ComponentInstance) &&
          e.definition.name == PARENT_NAME
        }

        if parent_idx
          candidate = path[parent_idx + 1]
          if candidate.is_a?(Sketchup::ComponentInstance) &&
             candidate.definition.name =~ CHILD_REGEX
            @hovered_instance       = candidate
            rev_idx                 = path.size - 1 - (parent_idx + 1)
            @hovered_transformation = ph.transformation_at(rev_idx)
            @parent_inst            = path[parent_idx]
          else
            @hovered_instance = @parent_inst = nil
          end
        else
          @hovered_instance = @parent_inst = nil
        end

        view.invalidate
      end

      def draw(view)
        return unless @hovered_instance && @hovered_transformation

        view.line_width    = 2
        view.drawing_color = 'red'
        bounds  = @hovered_instance.definition.bounds
        corners = (0..7).map { |i| bounds.corner(i) }
        world   = corners.map { |pt| pt.transform(@hovered_transformation) }

        view.draw(GL_LINE_LOOP, world[0], world[1], world[3], world[2])
        view.draw(GL_LINE_LOOP, world[4], world[5], world[7], world[6])
        view.draw(GL_LINES,
                  world[0], world[4], world[1], world[5],
                  world[2], world[6], world[3], world[7])
      end

      def onLButtonDown(flags, x, y, view)
        return unless @hovered_instance&.valid? && @parent_inst&.valid?

        model = view.model
        if model.active_path&.include?(@parent_inst)
          UI.messagebox("Quittez le mode édition de “#{PARENT_NAME}” d’abord.")
          return
        end

        model.start_operation('Duplicate Sub-Component', true)
        begin
          @parent_inst.make_unique

          t_child_global  = @hovered_instance.transformation
          t_parent_global = @parent_inst.transformation
          t_local         = t_parent_global.inverse * t_child_global

          old_dict = @hovered_instance.attribute_dictionary('dynamic_attributes', false)

          ents     = @parent_inst.definition.entities
          new_inst = ents.add_instance(@hovered_instance.definition, t_local)
          new_inst.make_unique
          @last_new_inst = new_inst

          if old_dict
            new_dict = new_inst.attribute_dictionary('dynamic_attributes', true)
            old_dict.each_pair { |k, v| new_dict[k] = v }
          end

          new_inst.transform!(Geom::Transformation.translation([0, 0, 32.5.cm]))
          model.commit_operation
        rescue => e
          model.abort_operation
          UI.messagebox("Erreur lors de la duplication : #{e.message}")
        ensure
          # 1) rafraîchir la vue
          view.invalidate
          view.refresh
          # 2) redraw DC sur la nouvelle instance (si DC)
          redraw_dynamic(@last_new_inst)
        end
      end

      private

      # Copie de la logique dc_redraw_tool.rb pour forcer le redraw
      def redraw_dynamic(comp_instance)
        return unless comp_instance.is_a?(Sketchup::ComponentInstance)
        return unless comp_instance.attribute_dictionary('dynamic_attributes')

        # Eneroth DC Observers
        if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class) &&
           $dc_observers.get_latest_class
          $dc_observers.get_latest_class.redraw_with_undo(comp_instance)
        # SketchUp Dynamic Components Tools
        elsif defined?(Sketchup::DynamicComponents::Tools) &&
              Sketchup::DynamicComponents::Tools.respond_to?(:update_attributes)
          Sketchup::DynamicComponents::Tools.update_attributes(comp_instance)
        # Fallback standard
        elsif defined?($dc_functions) && $dc_functions.respond_to?(:redraw)
          $dc_functions.redraw(comp_instance)
        end

        comp_instance.dynamic_attributes_updated if comp_instance.respond_to?(:dynamic_attributes_updated)
      rescue => _ # ne jamais interrompre le flow en cas d’erreur
      end
    end

    # Barre d’outils et commande
    cmd = UI::Command.new('Duplication Bac/Tab') {
      Sketchup.active_model.select_tool(QuickDuplicateSubTool.new)
    }
    cmd.tooltip         = 'Dupliquer un bac/tab direct de “Rayonnage”'
    cmd.status_bar_text = 'Cliquez pour créer la copie en Z+'

    icon_folder = File.join(File.dirname(__FILE__), 'icons')
    icon_path   = File.join(icon_folder, 'duplicate_sub.png')
    if File.exist?(icon_path)
      cmd.small_icon = icon_path
      cmd.large_icon = icon_path
    end

    toolbar = UI::Toolbar.new('London_2D')
    toolbar.add_item(cmd)
    toolbar.show

    file_loaded(PLUGIN_ID)
  end
end








