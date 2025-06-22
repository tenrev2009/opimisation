# --- Chargement des dépendances ---
require 'sketchup.rb'

begin
  require 'sketchup-dynamic-components/ruby/dcfunctions.rb'
rescue LoadError
  UI.messagebox("L'extension 'Composants Dynamiques' est requise. Veuillez l'activer depuis le Gestionnaire d'extensions.")
end

# --- Définition des modules ---
module London2D
end

module London2D::BookInserter

  # --- Constantes ---
  PLUGIN_DIR = File.dirname(__FILE__)
  PATH_TO_RESOURCES = File.join(PLUGIN_DIR, 'icons')
  PATH_TO_COMPONENTS = File.join(PLUGIN_DIR, 'components')
  PATH_TO_BOOK_BLOCK = File.join(PATH_TO_COMPONENTS, 'book_block.skp')

  class BookPlacerTool
    
    def initialize
      @book_definition = nil
    end

    def activate
      puts "Outil 'BookPlacerTool' activé."
      @model = Sketchup.active_model
      @highlighted_component = nil
      
      begin
        @book_definition = @model.definitions.load(PATH_TO_BOOK_BLOCK)
      rescue => e
        UI.messagebox("Erreur: Impossible de charger le fichier du composant livre.\n#{e.message}")
        @model.select_tool(nil)
        return
      end
      
      Sketchup.set_status_text("Cliquez sur un composant pour y insérer le bloc de livres.")
    end
    
    # --- Les méthodes de l'outil (deactivate, onMouseMove, draw, etc.) sont stables et ne changent pas ---
    def deactivate(view)
      view.invalidate if view
      Sketchup.set_status_text("")
    end

    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper
      ph.do_pick(x, y)
      picked = ph.best_picked
      new_highlight = nil
      if picked
        current = picked
        until current.nil? || current.is_a?(Sketchup::ComponentInstance)
          current = current.parent
        end
        new_highlight = current if current.is_a?(Sketchup::ComponentInstance)
      end
      if @highlighted_component != new_highlight
        @highlighted_component = new_highlight
        view.invalidate
      end
    end
    
    def onLButtonDown(flags, x, y, view)
      if @highlighted_component && @highlighted_component.valid?
        parent_component = @highlighted_component
        UI.start_timer(0, false) do
          place_book_inside(parent_component)
        end
        @model.select_tool(nil)
      else
        puts "Clic dans le vide ou sur un objet non-valide."
      end
    end
    
    def draw(view)
      return unless @highlighted_component && @highlighted_component.valid?
      bounds = @highlighted_component.bounds
      view.drawing_color = "DodgerBlue"
      view.line_width = 3
      view.line_stipple = ""
      pts = (0..7).map { |i| bounds.corner(i) }
      view.draw(GL_LINE_LOOP, pts[0], pts[1], pts[3], pts[2])
      view.draw(GL_LINE_LOOP, pts[4], pts[5], pts[7], pts[6])
      view.draw(GL_LINES, pts[0], pts[4], pts[1], pts[5], pts[2], pts[6], pts[3], pts[7])
    end
    
    def onCancel(reason)
      @model.select_tool(nil)
    end
    
    private
    
    # --- MÉTHODE PRINCIPALE D'INSERTION ET DE MISE À JOUR ---
    def place_book_inside(parent_component)
      model = parent_component.model
      model.start_operation("Insérer et Mettre à Jour le Bloc de Livres", true)
      
      begin
        # --- Étape 1 : Insertion ---
        # Comme vous avez résolu la position, vous pouvez modifier la transformation ici si besoin.
        transformation = Geom::Transformation.new
        target_entities = parent_component.definition.entities
        new_book_instance = target_entities.add_instance(@book_definition, transformation)
        puts "Étape 1 : Bloc de livres inséré."

        # --- Étape 2 : Lancement de la mise à jour récursive ---
        # On commence par le PARENT, qui propagera les changements.
        puts "Étape 2 : Démarrage de la mise à jour récursive sur le parent..."
        update_dynamically_recursively(parent_component)

      rescue => e
        UI.messagebox("Une erreur est survenue :\n#{e.message}")
        model.abort_operation
      else
        model.commit_operation
        puts "Opération terminée avec succès."
        model.active_view.refresh
      end
    end

    # --- NOUVELLE FONCTION DE MISE À JOUR RÉCURSIVE ---
    def update_dynamically_recursively(instance)
      # On met d'abord à jour l'instance actuelle
      force_dc_update(instance)
      
      # Puis on parcourt ses enfants et on recommence
      instance.definition.entities.grep(Sketchup::ComponentInstance).each do |child|
        update_dynamically_recursively(child)
      end
    end
    
    # --- NOUVELLE FONCTION DE MISE À JOUR, BASÉE SUR VOTRE CODE QUI FONCTIONNE ---
    def force_dc_update(comp_instance)
      return unless comp_instance.attribute_dictionary('dynamic_attributes')
      
      puts " -> Mise à jour de '#{comp_instance.definition.name}'"
      
      # Priorité n°1 : Eneroth DC observers (méthode la plus fiable)
      if defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class) && $dc_observers.get_latest_class
        puts "    -> via Eneroth DC Observers"
        $dc_observers.get_latest_class.redraw_with_undo(comp_instance)
      else
        # Priorité n°2 : Votre méthode qui fonctionne, Tools.update_attributes
        if defined?(Sketchup::DynamicComponents::Tools) && Sketchup::DynamicComponents::Tools.respond_to?(:update_attributes)
          puts "    -> via Tools.update_attributes"
          Sketchup::DynamicComponents::Tools.update_attributes(comp_instance)
        end
      end
      
      # Notification finale, toujours une bonne pratique
      comp_instance.dynamic_attributes_updated if comp_instance.respond_to?(:dynamic_attributes_updated)
    end
    
  end

  class << self
    def activate_placer_tool
      Sketchup.active_model.select_tool(BookPlacerTool.new)
    end
  end

  unless file_loaded?(__FILE__)
    cmd = UI::Command.new("Insérer Bloc de Livres") { self.activate_placer_tool }
    cmd.small_icon = File.join(PATH_TO_RESOURCES, "london_books.png")
    cmd.large_icon = File.join(PATH_TO_RESOURCES, "london_books.png")
    cmd.tooltip = "Insérer un bloc de livres dans un composant"
    toolbar = UI::Toolbar.new("London_2D")
    toolbar.add_item(cmd)
    toolbar.restore
    UI.menu("Plugins").add_item(cmd)
    file_loaded(__FILE__)
  end

end