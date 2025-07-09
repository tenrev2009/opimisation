# --- bac_inserter.rb avec Aperçu Fantôme, Clonage d'Attributs, et MAJ Parent ---
# --- Version améliorée avec choix du composant à l'activation ---
require 'sketchup.rb'

begin
  require 'sketchup-dynamic-components/ruby/dcfunctions.rb'
rescue LoadError
  # UI.messagebox("L'extension 'Composants Dynamiques' est requise.")
end

module London2D
end

module London2D::BacInserter

  PLUGIN_DIR = File.dirname(__FILE__)
  PATH_TO_RESOURCES = File.join(PLUGIN_DIR, 'icons')
  PATH_TO_COMPONENTS = File.join(PLUGIN_DIR, 'components')
  
  # --- Chemins des composants ---
  PATH_TO_BAC_COMPONENT = File.join(PATH_TO_COMPONENTS, '04-BACS.skp')
  
  ### NOUVEAU : Définissez les chemins vers vos autres composants ici ###
  # !!! VÉRIFIEZ BIEN QUE CES NOMS DE FICHIERS SONT CORRECTS !!!
  PATH_TO_TABLETTE_COMPONENT = File.join(PATH_TO_COMPONENTS, 'TABLETTE.skp') 
  PATH_TO_TABLETTE_INCLINEE_COMPONENT = File.join(PATH_TO_COMPONENTS, 'TABLETTE-INCLINEE.skp') 

  # La logique de l'outil reste la même, il est juste rendu plus générique.
  # Le nom "BacPlacerTool" est conservé comme demandé.
  class BacPlacerTool
    
    SNAP_INCREMENT = 2.5.cm 

    ### MODIFICATION : L'initialisation accepte maintenant le chemin du composant à charger
    def initialize(component_path_to_load)
      @component_path = component_path_to_load
      @element_definition = nil # Renommé de @bac_definition pour plus de clarté
      @highlighted_component = nil
      @parent_origin = nil
      @parent_z_axis = nil
      @snapped_insertion_point = nil
    end

    def activate
      puts "Outil 'Placer Élément' activé."
      @model = Sketchup.active_model
      @highlighted_component = nil
      @parent_origin = nil
      @parent_z_axis = nil
      @snapped_insertion_point = nil
      
      begin
        ### MODIFICATION : Charge le composant depuis le chemin passé à l'initialisation
        @element_definition = @model.definitions.load(@component_path)
      rescue => e
        UI.messagebox("Erreur: Impossible de charger le composant.\nChemin: #{@component_path}\n\n#{e.message}")
        @model.select_tool(nil)
        return
      end
      
      Sketchup.set_status_text("Survolez un composant parent, cliquez pour placer l'élément.")
      Sketchup.active_model.active_view.invalidate 
    end
    
    def deactivate(view)
      view.invalidate if view
      Sketchup.set_status_text("")
    end

    # La logique de onMouseMove reste inchangée
    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      picked_entity = ph.best_picked
      new_highlight = nil
      if picked_entity
        current = picked_entity
        until current.nil? || current.is_a?(Sketchup::ComponentInstance)
          current = current.parent
        end
        new_highlight = current if current.is_a?(Sketchup::ComponentInstance)
      end

      needs_invalidate = false
      if @highlighted_component != new_highlight
        @highlighted_component = new_highlight
        if @highlighted_component
          parent_transform = @highlighted_component.transformation
          @parent_origin = parent_transform.origin
          @parent_z_axis = parent_transform.zaxis.normalize
        else
          @parent_origin = nil
          @parent_z_axis = nil
        end
        @snapped_insertion_point = nil 
        needs_invalidate = true
      end

      old_snapped_point = @snapped_insertion_point
      if @highlighted_component && @parent_origin && @parent_z_axis
        mouse_ip = view.inputpoint(x, y)
        if mouse_ip.valid?
            mouse_point_3d = mouse_ip.position
            projected_point_on_axis = mouse_point_3d.project_to_line(@parent_origin, @parent_z_axis)
            vector_to_projection = projected_point_on_axis - @parent_origin
            distance_along_z = vector_to_projection.dot(@parent_z_axis)
            current_snapped_z_value = (distance_along_z / SNAP_INCREMENT).round * SNAP_INCREMENT
            @snapped_insertion_point = @parent_origin.offset(@parent_z_axis, current_snapped_z_value)
            needs_invalidate = true if @snapped_insertion_point != old_snapped_point
        else
            @snapped_insertion_point = nil 
            needs_invalidate = true if old_snapped_point 
        end
      else
        if @snapped_insertion_point 
          @snapped_insertion_point = nil
          needs_invalidate = true
        end
      end
      if needs_invalidate
        view.invalidate
      end
    end
    
    # La logique de draw reste inchangée, elle utilise maintenant @element_definition
    def draw(view)
      if @snapped_insertion_point && @element_definition
        preview_transform = Geom::Transformation.translation(@snapped_insertion_point)
        bounds = @element_definition.bounds
        transformed_pts = Array.new(8) { |i| bounds.corner(i).transform(preview_transform) }
        view.drawing_color = [0, 255, 0, 255]; view.line_width = 2; view.line_stipple = ""
        view.draw(GL_LINE_LOOP, transformed_pts[0], transformed_pts[1], transformed_pts[3], transformed_pts[2])
        view.draw(GL_LINE_LOOP, transformed_pts[4], transformed_pts[5], transformed_pts[7], transformed_pts[6])
        view.draw(GL_LINES, transformed_pts[0], transformed_pts[4], transformed_pts[1], transformed_pts[5], 
                            transformed_pts[2], transformed_pts[6], transformed_pts[3], transformed_pts[7])
      elsif @highlighted_component && @highlighted_component.valid?
          bounds = @highlighted_component.bounds; view.drawing_color = "DodgerBlue"; view.line_width = 2; view.line_stipple = ""
          pts = (0..7).map { |i| bounds.corner(i) }
          view.draw(GL_LINE_LOOP, pts[0], pts[1], pts[3], pts[2]); view.draw(GL_LINE_LOOP, pts[4], pts[5], pts[7], pts[6])
          view.draw(GL_LINES, pts[0], pts[4], pts[1], pts[5], pts[2], pts[6], pts[3], pts[7])
      end
    end

    # La logique de onLButtonDown reste inchangée
    def onLButtonDown(flags, x, y, view)
      if @highlighted_component && @snapped_insertion_point && @highlighted_component.valid?
        insertion_transform = Geom::Transformation.translation(@snapped_insertion_point)
        ### MODIFICATION : Utilise @element_definition au lieu de @bac_definition
        UI.start_timer(0, false) { place_element_inside(@highlighted_component, insertion_transform, @element_definition) }
        @model.select_tool(nil)
      elsif @highlighted_component && @highlighted_component.valid? 
        puts "Insertion à l'origine du parent (pas de point de snap actif)."
        UI.start_timer(0, false) { place_element_inside(@highlighted_component, Geom::Transformation.new, @element_definition) }
        @model.select_tool(nil)
      else
        puts "Clic invalide."
      end
    end
        
    def onCancel(reason); @model.select_tool(nil); end
    
    private
    
    # La logique de cette méthode est inchangée
    def place_element_inside(parent_component, transformation_for_new_instance, element_definition_to_insert)
      model = parent_component.model
      model.start_operation("Insérer Élément et Mettre à Jour", true)
      
      begin
        target_entities = parent_component.definition.entities
        new_element_instance = target_entities.add_instance(element_definition_to_insert, transformation_for_new_instance)
        
        source_dc_dict = element_definition_to_insert.attribute_dictionary('dynamic_attributes')
        instance_dc_dict = new_element_instance.attribute_dictionary('dynamic_attributes', true) 

        if source_dc_dict && instance_dc_dict
          source_dc_dict.each_pair do |key, value|
            new_element_instance.set_attribute('dynamic_attributes', key, value)
          end
        else
          puts "AVERTISSEMENT: Impossible de cloner les attributs dynamiques."
        end
        
        update_dynamically_recursively(parent_component)

      rescue => e
        UI.messagebox("Une erreur est survenue :\n#{e.message}\n#{e.backtrace.first}")
        model.abort_operation
      else
        model.commit_operation
        puts "Opération terminée avec succès."
        model.active_view.refresh
      end
    end

    # La logique de cette méthode est inchangée
    def update_dynamically_recursively(instance)
      force_dc_update(instance)
      instance.definition.entities.grep(Sketchup::ComponentInstance).each do |child|
        update_dynamically_recursively(child)
      end
    end
    
    # La logique de cette méthode est inchangée
    def force_dc_update(comp_instance)
      return unless comp_instance.attribute_dictionary('dynamic_attributes')
      puts " -> Mise à jour de '#{comp_instance.definition.name}'"
      if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class) && $dc_observers.get_latest_class
        puts "    -> via Eneroth DC Observers"
        $dc_observers.get_latest_class.redraw_with_undo(comp_instance)
      elsif defined?(Sketchup::DynamicComponents::Tools) && Sketchup::DynamicComponents::Tools.respond_to?(:update_attributes)
        puts "    -> via Tools.update_attributes"
        Sketchup::DynamicComponents::Tools.update_attributes(comp_instance)
      end
      comp_instance.dynamic_attributes_updated if comp_instance.respond_to?(:dynamic_attributes_updated)
    end    
  end

  ### NOUVEAU : Logique pour afficher le choix et lancer le bon outil
  class << self
    def show_component_choice_and_activate_tool
      # Crée une boîte de dialogue avec une liste déroulante
      prompts = ["Type d'élément à insérer :"]
      defaults = ["Bac"]
      list_options = "Bac|Tablette|Tablette Inclinée"
      
      # Affiche la boîte de dialogue
      results = UI.inputbox(prompts, defaults, [list_options], "Choisir un composant à insérer")
      
      # Si l'utilisateur clique sur "Annuler", results sera nil
      return unless results
      
      user_choice = results[0]
      
      # Détermine le chemin du composant en fonction du choix
      component_path = case user_choice
                       when "Bac"
                         PATH_TO_BAC_COMPONENT
                       when "Tablette"
                         PATH_TO_TABLETTE_COMPONENT
                       when "Tablette Inclinée"
                         PATH_TO_TABLETTE_INCLINEE_COMPONENT
                       else
                         UI.messagebox("Choix non reconnu.")
                         return
                       end
      
      # Crée une instance de l'outil avec le bon chemin et l'active
      tool = BacPlacerTool.new(component_path)
      Sketchup.active_model.select_tool(tool)
    end
  end

  ### MODIFICATION : La commande de la barre d'outils appelle maintenant la méthode de choix
  unless file_loaded?(__FILE__) 
    # Le nom de la commande est rendu plus générique
    cmd_inserter = UI::Command.new("Insérer Élément") { self.show_component_choice_and_activate_tool }
    
    # L'icône reste celle du bac, mais vous pouvez la changer pour une plus générique
    cmd_inserter.small_icon = File.join(PATH_TO_RESOURCES, "bac.png")
    cmd_inserter.large_icon = File.join(PATH_TO_RESOURCES, "bac.png")
    
    # La tooltip est mise à jour pour être plus descriptive
    cmd_inserter.tooltip = "Insérer un élément (Bac, Tablette, etc.)"
    
    toolbar = UI::Toolbar.new("London_2D")
    toolbar.add_item(cmd_inserter)
    toolbar.restore
    
    UI.menu("Plugins").add_item(cmd_inserter)
    
    file_loaded(__FILE__)
  end
end