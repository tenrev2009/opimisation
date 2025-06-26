# --- dc_options_tool.rb ---
require 'sketchup.rb'

# Aucune dépendance 'require' spécifique nécessaire si votre code original
# fonctionne en supposant que $dc_observers est déjà disponible.

module London2D
end

module London2D::DCOptionsTool

  PLUGIN_DIR = File.dirname(__FILE__)
  # Chemin vers le dossier d'icônes.
  # Si dc_options_tool.rb est dans London_2D/ et icons/ est dans London_2D/icons/
  PATH_TO_RESOURCES = File.join(PLUGIN_DIR, 'icons') 
  # Si dc_options_tool.rb est dans London_2D/ et icons/ est dans un dossier parent London_2D/ (ce qui est moins courant)
  # PATH_TO_RESOURCES = File.join(File.dirname(PLUGIN_DIR), 'icons')
  # Adaptez si votre structure est différente.

  class << self
    
    # --- VOTRE CODE ORIGINAL INTÉGRÉ DIRECTEMENT ---
    def show_or_hide_dc_options # Nouveau nom pour éviter les conflits
      # On vérifie si $dc_observers est défini pour éviter une erreur si l'extension
      # d'Eneroth (ou celle qui définit $dc_observers) n'est pas chargée.
      unless defined?($dc_observers) && $dc_observers.respond_to?(:get_latest_class)
        UI.messagebox("L'extension nécessaire pour les options des composants dynamiques ($dc_observers) n'est pas disponible.")
        return
      end

      # On s'assure que get_latest_class retourne quelque chose
      dialog_manager = $dc_observers.get_latest_class
      unless dialog_manager
        UI.messagebox("Impossible d'accéder au gestionnaire de dialogue des options DC.")
        return
      end

      # On vérifie que les méthodes attendues existent sur le dialog_manager
      # pour éviter des NoMethodError si l'API d'Eneroth changeait.
      unless dialog_manager.respond_to?(:configure_dialog_is_visible) && \
             dialog_manager.respond_to?(:close_configure_dialog) && \
             dialog_manager.respond_to?(:show_configure_dialog)
        UI.messagebox("Les méthodes nécessaires pour gérer la fenêtre d'options DC ne sont pas disponibles sur le dialog_manager.")
        return
      end

      # Votre logique originale
      if dialog_manager.configure_dialog_is_visible
        puts "Fermeture de la fenêtre d'options DC."
        dialog_manager.close_configure_dialog
      else
        puts "Ouverture de la fenêtre d'options DC."
        # Si la méthode show_configure_dialog a besoin de la sélection, 
        # elle la récupérera probablement elle-même via Sketchup.active_model.selection
        # ou elle est conçue pour fonctionner avec le dernier composant interagi.
        dialog_manager.show_configure_dialog
      end
      
      # Votre ligne pour revenir à l'outil de sélection.
      Sketchup.send_action("selectSelectionTool:")
    end
    # --- FIN DE VOTRE CODE ORIGINAL INTÉGRÉ ---

  end # fin de class << self

  # --- Création de l'interface ---
  unless file_loaded?(__FILE__)
    # La commande appelle maintenant notre méthode wrapper
    cmd_options = UI::Command.new("Options du Composant") { self.show_or_hide_dc_options }
    
    cmd_options.small_icon = File.join(PATH_TO_RESOURCES, "options.png")
    cmd_options.large_icon = File.join(PATH_TO_RESOURCES, "options.png")
    cmd_options.tooltip = "Ouvre/Ferme les options du composant dynamique" # Changé pour refléter le toggle
    
    toolbar = UI::Toolbar.new("London_2D") # Assurez-vous que c'est le nom de votre barre
    toolbar.add_item(cmd_options)
    toolbar.restore
    
    # Optionnel: ajouter au menu "Plugins"
    # plugins_menu = UI.menu("Plugins")
    # london2d_submenu = plugins_menu.submenu("London2D") # Crée un sous-menu si vous voulez
    # london2d_submenu.add_item(cmd_options)
    # Ou directement :
    UI.menu("Plugins").add_item(cmd_options)
    
    file_loaded(__FILE__)
  end

end