# --- bac_inserter.rb avec Overlay, Snapping, et MAJ Ciblée sur l'Enfant ---
require 'sketchup.rb'

begin
  require 'sketchup-dynamic-components/ruby/dcfunctions.rb'
rescue LoadError
end

module London2D
end

module London2D::BacInserter

  PLUGIN_DIR = File.dirname(__FILE__)
  # Assumant que bac_inserter.rb est dans London_2D/bac_inserter/
  # et que icons/ et components/ sont DANS CE SOUS-DOSSIER
  PATH_TO_RESOURCES = File.join(PLUGIN_DIR, 'icons')
  PATH_TO_COMPONENTS = File.join(PLUGIN_DIR, 'components')
  PATH_TO_BAC_COMPONENT = File.join(PATH_TO_COMPONENTS, '04-BACS.skp') # VÉRIFIEZ CECI

  class CotationOverlay < Sketchup::Overlay
    SNAP_INCREMENT = 2.5.cm 
    AXIS_LINE_LENGTH = 50.cm
    NUMBER_OF_COTATIONS_TO_SHOW = 2

    def initialize(tool_instance)
      overlay_id = "com.london2d.bacinserter.cotationoverlay.#{Time.now.to_f}"
      overlay_name = "Cotations Bac Inserter"
      super(overlay_id, overlay_name)
      @tool = tool_instance
    end

    def draw(view)
      return unless @tool.highlighted_component && @tool.parent_origin && @tool.parent_z_axis
      view.drawing_color = "Blue"
      view.line_width = 3; view.line_stipple = ""
      pt1 = @tool.parent_origin.offset(@tool.parent_z_axis.reverse, AXIS_LINE_LENGTH)
      pt2 = @tool.parent_origin.offset(@tool.parent_z_axis, AXIS_LINE_LENGTH)
      view.draw_line(pt1, pt2)
      if @tool.snapped_insertion_point
        view.drawing_color = "Red"; view.line_width = 3
        view.draw_points(@tool.snapped_insertion_point, 12, 4, "Red")
        view.drawing_color = "Black"
        text_offset = view.camera.xaxis * 3.cm
        (-NUMBER_OF_COTATIONS_TO_SHOW..NUMBER_OF_COTATIONS_TO_SHOW).each do |i|
          z_val = @tool.current_snapped_z_value + (i * SNAP_INCREMENT)
          pt_on_axis = @tool.parent_origin.offset(@tool.parent_z_axis, z_val)
          disp_cm = (z_val.to_cm == -0.0) ? 0.0 : z_val.to_cm
          label = sprintf("%.1f cm", disp_cm)
          view.draw_text(pt_on_axis.offset(text_offset), label)
        end
      end
    end
  end

  class BacPlacerTool 
    attr_reader :highlighted_component, :parent_origin, :parent_z_axis, 
                  :snapped_insertion_point, :current_snapped_z_value
    SNAP_INCREMENT = CotationOverlay::SNAP_INCREMENT

    def initialize
      @bac_definition = nil; @highlighted_component = nil; @parent_origin = nil
      @parent_z_axis = nil; @snapped_insertion_point = nil
      @current_snapped_z_value = 0.0; @overlay = nil
    end

    def activate
      puts "Outil 'BacPlacerTool' (MAJ Enfant Seulement) activé."
      @model = Sketchup.active_model
      # ... (réinitialisations) ...
      @highlighted_component = nil; @parent_origin = nil; @parent_z_axis = nil
      @snapped_insertion_point = nil; @current_snapped_z_value = 0.0
      begin
        @bac_definition = @model.definitions.load(PATH_TO_BAC_COMPONENT)
      rescue => e
        UI.messagebox("Erreur chargement BAC: #{e.message}"); @model.select_tool(nil); return
      end
      if @overlay && @model.active_view.overlays.include?(@overlay)
        @model.active_view.remove_overlay(@overlay) # Sécurité
      end
      @overlay = CotationOverlay.new(self)
      @model.active_view.add_overlay(@overlay)
      @model.active_view.invalidate 
      Sketchup.set_status_text("Survolez parent, cliquez pour placer BAC sur axe Z.")
    end
    
    def deactivate(view)
      if @overlay && view && view.overlays.include?(@overlay)
        view.remove_overlay(@overlay); @overlay = nil; view.invalidate
      end
      Sketchup.set_status_text("")
    end

    def onMouseMove(flags, x, y, view) # Logique de snapping
      ph = view.pick_helper; ph.do_pick(x, y); picked = ph.best_picked
      new_hl = picked ? (current = picked; until current.nil? || current.is_a?(Sketchup::ComponentInstance); current = current.parent; end; current.is_a?(Sketchup::ComponentInstance) ? current : nil) : nil
      needs_redraw = false
      if @highlighted_component != new_hl
        @highlighted_component = new_hl
        if @highlighted_component
          pt = @highlighted_component.transformation; @parent_origin = pt.origin; @parent_z_axis = pt.zaxis.normalize
        else
          @parent_origin = nil; @parent_z_axis = nil
        end
        @snapped_insertion_point = nil; @current_snapped_z_value = 0.0; needs_redraw = true
      end
      old_snap_pt = @snapped_insertion_point
      if @highlighted_component && @parent_origin && @parent_z_axis
        ip = view.inputpoint(x,y); unless ip.valid?; if @snapped_insertion_point; @snapped_insertion_point=nil; @current_snapped_z_value=0.0; needs_redraw=true; end; view.invalidate if needs_redraw; return; end
        proj_pt = ip.position.project_to_line(@parent_origin, @parent_z_axis)
        dist_z = (proj_pt - @parent_origin).dot(@parent_z_axis)
        @current_snapped_z_value = (dist_z / SNAP_INCREMENT).round * SNAP_INCREMENT
        @snapped_insertion_point = @parent_origin.offset(@parent_z_axis, @current_snapped_z_value)
        needs_redraw = true if @snapped_insertion_point != old_snap_pt
      else
        if @snapped_insertion_point; @snapped_insertion_point=nil; @current_snapped_z_value=0.0; needs_redraw=true; end
      end
      view.invalidate if needs_redraw
    end
    
    def draw(view); end # Géré par Overlay

    def onLButtonDown(flags, x, y, view)
      if @highlighted_component && @snapped_insertion_point && @highlighted_component.valid?
        ins_trans = Geom::Transformation.translation(@snapped_insertion_point)
        UI.start_timer(0, false) { place_element_inside(@highlighted_component, ins_trans, @bac_definition) }
        @model.select_tool(nil)
      end
    end
        
    def onCancel(reason); @model.select_tool(nil); end
    
    private
    
    def place_element_inside(parent_component, transformation_for_new_instance, element_definition_to_insert)
      model = parent_component.model
      model.start_operation("Insérer BAC et MAJ Enfant", true)
      new_element_instance = nil
      begin
        target_entities = parent_component.definition.entities
        new_element_instance = target_entities.add_instance(element_definition_to_insert, transformation_for_new_instance)
        puts "Étape 1 : BAC inséré au point snappé."

        # --- Étape 2 : CLONAGE COMPLET DES ATTRIBUTS DE LA DÉFINITION VERS L'INSTANCE ---
        source_dc_dict = element_definition_to_insert.attribute_dictionary('dynamic_attributes')
        instance_dc_dict = new_element_instance.attribute_dictionary('dynamic_attributes', true) 
        if source_dc_dict && instance_dc_dict
          puts "Clonage des attributs de '#{element_definition_to_insert.name}' vers la nouvelle instance..."
          source_dc_dict.each_pair { |k, v| new_element_instance.set_attribute('dynamic_attributes', k, v) }
          puts "Clonage des attributs terminé."
        end
        
        # --- Étape 3 : MISE À JOUR DE LA NOUVELLE INSTANCE ENFANT UNIQUEMENT ---
        if new_element_instance
          puts "Étape 3 : Démarrage de la mise à jour sur la NOUVELLE INSTANCE BAC '#{new_element_instance.definition.name}'..."
          force_dc_update(new_element_instance) # Met à jour l'enfant directement
        end

      rescue => e
        UI.messagebox("Erreur insertion/MAJ BAC:\n#{e.message}\n#{e.backtrace.first}"); model.abort_operation
      else
        model.commit_operation; puts "Opération BAC (MAJ Enfant) terminée."; model.active_view.refresh
      end
    end
    
    def force_dc_update(comp_instance) # Cette fonction ne fait pas de récursion
      return unless comp_instance.attribute_dictionary('dynamic_attributes')
      puts " -> Mise à jour ciblée de '#{comp_instance.definition.name}'"
      if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class) && $dc_observers.get_latest_class
        $dc_observers.get_latest_class.redraw_with_undo(comp_instance)
      elsif defined?(Sketchup::DynamicComponents::Tools) && Sketchup::DynamicComponents::Tools.respond_to?(:update_attributes)
        Sketchup::DynamicComponents::Tools.update_attributes(comp_instance)
      end
      comp_instance.dynamic_attributes_updated if comp_instance.respond_to?(:dynamic_attributes_updated)
    end    
  end

  class << self
    def activate_bac_placer_tool; Sketchup.active_model.select_tool(BacPlacerTool.new); end
  end

  unless file_loaded?(__FILE__) 
    cmd = UI::Command.new("Insérer BAC (SnapZ, MAJ Enfant)") { self.activate_bac_placer_tool }
    cmd.small_icon = File.join(PATH_TO_RESOURCES, "bac.png")
    cmd.large_icon = File.join(PATH_TO_RESOURCES, "bac.png")
    cmd.tooltip = "Insérer un BAC (MAJ Enfant uniquement)"
    tb = UI::Toolbar.new("London_2D"); tb.add_item(cmd); tb.restore
    UI.menu("Plugins").add_item(cmd)
    file_loaded(__FILE__)
  end
end