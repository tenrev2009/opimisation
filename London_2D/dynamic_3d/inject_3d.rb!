require 'sketchup.rb'

module London2D
  module Dynamic3D

    DICT = "London_2D"
    SHELF_ATTRS = {
      100 => "etagere_100_cm",
      90  => "etagere_90_cm",
      75  => "etagere_75_cm",
      50  => "etagere_50_cm"
    }

    # -------------------------------------------------------------------
    # Outil interactif de placement du composant 3D entre 2 points
    # -------------------------------------------------------------------
    class ComponentPlacementTool
      def initialize(definition, point1, shelf_counts, nb_tablette, hauteur_pouces)
        @definition     = definition
        @point1         = point1
        @shelf_counts   = shelf_counts
        @nb_tablette    = nb_tablette
        @hauteur_pouces = hauteur_pouces

        @ip2            = Sketchup::InputPoint.new
        @final_pt2      = nil
        @view           = Sketchup.active_model.active_view
      end

      def activate
        UI.set_status_text(
          "Déplacez la souris pour snap aux points remarquables, puis cliquez pour valider Point 2.",
          SB_PROMPT
        )
        @view.invalidate
      end

      def deactivate(view)
        view.invalidate
        UI.set_status_text("", SB_PROMPT)
      end

      # Mise à jour de la prévisualisation
      def onMouseMove(flags, x, y, view)
        @ip2.pick(view, x, y)
        view.invalidate
      end

      # Dessin du preview : P1, P2 provisoire, et ligne
      def draw(view)
        # Point 1 fixe (rouge)
        view.drawing_color = 'red'
        view.line_width    = 4
        view.draw_points(@point1, 10, 1)

        # Point 2 provisoire (vert) et ligne (bleu)
        if @ip2.valid?
          view.drawing_color = 'green'
          view.line_width    = 4
          view.draw_points(@ip2.position, 8, 1)

          view.drawing_color = 'blue'
          view.line_width    = 2
          view.draw_lines(@point1, @ip2.position)
        end
      end

      # Validation du second point
      def onLButtonDown(flags, x, y, view)
        if @ip2.valid?
          @final_pt2 = @ip2.position
          place_and_finish
        else
          UI.messagebox(
            "Veuillez cliquer sur un point remarquable (extrémité, milieu, intersection).",
            MB_OK
          )
        end
      end

      private

      def place_and_finish
        model = Sketchup.active_model
        model.start_operation("Insérer 3D dynamique", true)

        # Calcul de la transformation axes
        vec   = @point1.vector_to(@final_pt2).normalize
        xaxis = vec
        zaxis = Z_AXIS
        yaxis = zaxis * xaxis
        zaxis = xaxis * yaxis
        transform = Geom::Transformation.axes(@point1, xaxis, yaxis, zaxis)

        # Insertion du composant 3D principal
        comp3d = model.active_entities.add_instance(@definition, transform)

        # Injection des attributs dynamiques DANS LE COMPOSANT PARENT (comp3d)
        da = "dynamic_attributes"
        comp3d.set_attribute(da, "nb_100",     @shelf_counts[100])
        comp3d.set_attribute(da, "nb_90",      @shelf_counts[90])
        comp3d.set_attribute(da, "nb_75",      @shelf_counts[75])
        comp3d.set_attribute(da, "nb_50",      @shelf_counts[50])
        comp3d.set_attribute(da, "nb_tablette",@nb_tablette)
        comp3d.set_attribute(da, "hauteur",    @hauteur_pouces)
        
        # *** DEBUT DE LA LOGIQUE DE MISE À JOUR EXACTEMENT COMME DANS TON SCRIPT FONCTIONNEL ***

        # 1. Déclencher le redessin du composant PARENT
        # C'est cette méthode spécifique qui, selon toi, fonctionne et doit être appelée en premier pour le DC.
        if defined?($dc_observers) && $dc_observers.get_latest_class
          $dc_observers.get_latest_class.redraw_with_undo(comp3d)
        else
          # Fallback si l'extension DC n'est pas active ou $dc_observers non défini
          UI.messagebox("L'extension Dynamic Components n'est pas active ou non initialisée. Le composant pourrait ne pas se mettre à jour automatiquement.", UI::WARNING)
          # Tentative avec l'API standard comme fallback si le module $dc_observers n'est pas disponible
          if defined?(Sketchup::DynamicComponents::Tools)
            Sketchup::DynamicComponents::Tools.update_attributes(comp3d)
            # Pas de redraw_all_d_c_instances ici, car la stratégie est différente.
          end
        end
        # Cette ligne est souvent redondante si les méthodes ci-dessus sont appelées
        comp3d.dynamic_attributes_updated if comp3d.respond_to?(:dynamic_attributes_updated)

        # 2. Propagation aux enfants dynamiques
        # Ceci est appelé APRÈS le redraw_with_undo du parent, comme dans ton script fonctionnel.
        # Cela modifie les attributs des *définitions* des enfants,
        # sans les redessiner individuellement ici.
        London2D::Dynamic3D.update_children_dynamic(
          comp3d, @shelf_counts, @nb_tablette, @hauteur_pouces
        )

        # *** FIN DE LA LOGIQUE DE MISE À JOUR ***

        model.commit_operation # Le commit est fait APRES les appels de mise à jour, comme dans ton script
        model.active_view.refresh
        UI.messagebox("Insertion 3D terminée et composant mis à jour.", MB_OK)

        Sketchup.active_model.tools.pop_tool
      end
    end


    # -------------------------------------------------------------------
    # Point d'entrée : initialise et lance ComponentPlacementTool
    # -------------------------------------------------------------------
    def self.inject_dynamic_3d
      model = Sketchup.active_model
      sel   = model.selection.grep(Sketchup::ComponentInstance)
                  .select { |i| i.get_attribute(DICT, "longueur_totale_cm") }
      unless sel.any?
        UI.messagebox("Sélectionnez un composant London_2D.", MB_OK)
        return
      end

      inst = sel.first
      skp3d_path = File.join(__dir__, "london_3d.skp")
      unless File.exist?(skp3d_path)
        UI.messagebox("Fichier london_3d.skp introuvable.", MB_OK)
        return
      end
      definition3d = model.definitions.load(skp3d_path)

      # Point 1 : origine du composant 2D
      origin = inst.transformation.origin

      # Lecture des attributs 2D
      counts = {}
      SHELF_ATTRS.each { |k, att| counts[k] = inst.get_attribute(DICT, att).to_i }
      nb_tab  = inst.get_attribute(DICT, "nb_tablettes_hauteur").to_i
      haut_cm = inst.get_attribute(DICT, "hauteur_cm").to_f
      haut_in = (haut_cm / 2.54).round(2)

      # Lance l’outil interactif
      tool = ComponentPlacementTool.new(definition3d, origin, counts, nb_tab, haut_in)
      model.tools.push_tool(tool)
    end


    # -------------------------------------------------------------------
    # Mise à jour des enfants dynamiques
    # Cette fonction met à jour les ATTRIBUTS des *définitions* des sous-composants.
    # Elle ne contient PAS d'appels à redraw_with_undo pour les enfants,
    # comme dans ton script fonctionnel.
    # -------------------------------------------------------------------
    def self.update_children_dynamic(comp3d, shelf_counts, nb_tablette, hauteur_pouces)
      return unless comp3d && comp3d.definition && comp3d.definition.entities

      comp3d.definition.entities.grep(Sketchup::ComponentInstance).each do |child|
        if child.attribute_dictionaries && child.attribute_dictionaries.key?("dynamic_attributes")
          child.set_attribute("dynamic_attributes", "nb_100", shelf_counts[100])
          child.set_attribute("dynamic_attributes", "nb_90",  shelf_counts[90])
          child.set_attribute("dynamic_attributes", "nb_75",  shelf_counts[75])
          child.set_attribute("dynamic_attributes", "nb_50",  shelf_counts[50])
          child.set_attribute("dynamic_attributes", "nb_tablette", nb_tablette)
          child.set_attribute("dynamic_attributes", "hauteur", hauteur_pouces) 
        end
      end
    end


    # -------------------------------------------------------------------
    # Intégration dans l’UI : toolbar + menu Plugins
    # Ces parties sont laissées intactes par rapport à ton script original.
    # -------------------------------------------------------------------
    unless file_loaded?(__FILE__)
      icon = File.join(__dir__, "icons", "london_3d.png")

      cmd = UI::Command.new("Générer module 3D dynamique") { inject_dynamic_3d }
      cmd.tooltip         = "Place 3D entre Point 1 et Point 2"
      cmd.status_bar_text = "Outil placement 3D London_2D"
      cmd.large_icon      = icon
      cmd.small_icon      = icon

      toolbar = UI.toolbar("London_2D") || UI::Toolbar.new("London_2D")
      toolbar.add_item(cmd)
      toolbar.restore

      UI.menu("Plugins")
        .add_submenu("London_2D")
        .add_item("Générer module 3D dynamique") { inject_dynamic_3d }

      file_loaded(__FILE__)
    end

  end
end