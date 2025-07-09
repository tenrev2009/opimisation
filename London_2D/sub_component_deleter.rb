# Quick Delete Sub-Components Plugin for SketchUp
# Namespace: London_2D
# Toolbar icon: icons/delete_sub.png (same directory)
# Author: ChatGPT
# Date: 2025-07-02 (Corrected Version)

require 'sketchup.rb'
require 'extensions.rb'

module London_2D
  PLUGIN_ID = 'London_2D.quick_delete_sub'
  ICON_DIR = File.join(File.dirname(__FILE__), 'icons')

  unless file_loaded?(PLUGIN_ID)
    class QuickDeleteSubTool
      def initialize
        @hovered_instance = nil
        @hovered_transformation = nil
      end

      def activate
        puts '[QuickDeleteSub] Activated'
        Sketchup.set_status_text('Hover a sub-component; click to delete')
        Sketchup.active_model.active_view.invalidate
      end

      def deactivate(view)
        puts '[QuickDeleteSub] Deactivated'
        Sketchup.set_status_text('')
        view.invalidate if view
        @hovered_instance = nil
        @hovered_transformation = nil
      end

def onMouseMove(flags, x, y, view)
  ph = view.pick_helper
  # On augmente la zone de détection à 10 pixels autour du curseur
  ph.do_pick(x, y, 10)

  path = ph.path_at(0)
  inst = nil
  inst_path_index = -1

  if path
    path.reverse_each.with_index do |entity, i|
      if (entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)) &&
         entity.parent.is_a?(Sketchup::ComponentDefinition)
        
        name = entity.definition.name || ''
        if name =~ /tab|bac/i
          inst = entity
          inst_path_index = path.length - 1 - i
          break
        end
      end
    end
  end

  if inst && inst.valid?
    if @hovered_instance != inst
      @hovered_instance = inst
      @hovered_transformation = ph.transformation_at(inst_path_index)
      puts "[QuickDeleteSub] Hovering instance ID=#{inst.entityID} (#{inst.definition.name})"
    end
  else
    @hovered_instance = nil
    @hovered_transformation = nil
  end
  
  view.invalidate
rescue => e
  puts "[QuickDeleteSub] onMouseMove error: #{e.message}"
end

      def draw(view)
        return unless @hovered_instance && @hovered_instance.valid? && @hovered_transformation

        view.line_width = 2
        view.drawing_color = 'red'

        local_bounds = @hovered_instance.definition.bounds
        corners = (0..7).map { |i| local_bounds.corner(i) }
        world_corners = corners.map { |pt| pt.transform(@hovered_transformation) }
        
        view.draw(GL_LINE_LOOP, world_corners[0], world_corners[1], world_corners[3], world_corners[2])
        view.draw(GL_LINE_LOOP, world_corners[4], world_corners[5], world_corners[7], world_corners[6])
        view.draw(GL_LINES,
          world_corners[0], world_corners[4],
          world_corners[1], world_corners[5],
          world_corners[2], world_corners[6],
          world_corners[3], world_corners[7]
        )
      rescue => e
        puts "[QuickDeleteSub] draw error: #{e.message}"
      end

      def onLButtonDown(flags, x, y, view)
        return unless @hovered_instance && @hovered_instance.valid?
        model = view.model
        name = @hovered_instance.definition.name rescue 'Component'
        model.start_operation('Delete Sub-Component', true)
        @hovered_instance.erase!
        model.commit_operation
        puts "[QuickDeleteSub] Deleted #{name}"
        @hovered_instance = nil
        @hovered_transformation = nil
        view.invalidate
      rescue => e
        puts "[QuickDeleteSub] onLButtonDown error: #{e.message}"
        model.abort_operation
      end
    end # Fin de la classe QuickDeleteSubTool

    cmd = UI::Command.new('QuickDeleteSub') do
      Sketchup.active_model.select_tool(QuickDeleteSubTool.new)
    end
    
    ico_path = File.join(ICON_DIR, 'delete_sub.png')
    if File.exist?(ico_path)
      cmd.small_icon = ico_path
      cmd.large_icon = ico_path
    else
      puts "Warning: Icon file not found at #{ico_path}"
    end

    cmd.tooltip = 'Quick Delete Sub-Component'
    cmd.status_bar_text = 'Hover a sub-component; click to delete'
    
    tb = UI::Toolbar.new('London_2D')
    tb.add_item(cmd)
    tb.show

    file_loaded(PLUGIN_ID)
  end # Fin du bloc 'unless file_loaded?'
end # Fin du module London_2D







