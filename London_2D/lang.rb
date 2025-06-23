module London2D
  LANG = Sketchup.get_locale.start_with?("fr") ? :fr : :en

  TEXTS = {
    fr: {
      plugin_name:          "London_2D",
      calculator_title:     "Créer des étagères London_2D",
      calculator_tooltip:   "London_2D",
      calculator_status:    "Créer des étagères sur 2 points",
      rapport_menu:         "Rapport HTML London_2D",
      profondeur_prompt:    "Profondeur (cm)",
      choix_tailles:        "Choix des longueurs d'étagère",
      valider:              "Valider",
      no_component:         "Aucun composant London_2D trouvé.",
      longueur_totale:      "Longueur disponible (cm)",
      longueur_reelle:      "Longueur réelle utilisée (cm)",
      espace_restant:       "Espace restant (cm)",
      profondeur:           "Profondeur (cm)",
      nom:                  "Nom",
      books_per_meter:      "Nombre de livres par mètre linéaire :",
      capacity_title:       "Estimation de capacité",
      start_point_status:   "Cliquez pour placer le point de départ",
      end_point_status:     "Cliquez pour placer le point d'arrivée",
      preview_status:       "Aperçu affiché. Tab pour inverser, clic pour valider.",
      no_size_selected:     "Aucune taille sélectionnée.",
      param_dialog_title:   "Paramètres",
      insertion_done:       "Insertion 3D terminée et composant mis à jour.",
      select_component:     "Sélectionnez un composant London_2D.",
      file_not_found:       "Fichier london_3d.skp introuvable.",
      click_point_hint:     "Veuillez cliquer sur un point remarquable (extrémité, milieu, intersection).",
      dc_not_active:        "L'extension Dynamic Components n'est pas active ou non initialisée. Le composant pourrait ne pas se mettre à jour automatiquement.",
      book_inserter_status: "Cliquez sur un composant pour y insérer le bloc de livres.",
      extension_required:   "L'extension 'Composants Dynamiques' est requise. Veuillez l'activer depuis le Gestionnaire d'extensions.",
      book_load_error:      "Erreur: Impossible de charger le fichier du composant livre.",
      insert_book_command:  "Insérer Bloc de Livres",
      insert_book_tooltip:  "Insérer un bloc de livres dans un composant",
      generic_error:        "Une erreur est survenue :"
    },

    en: {
      plugin_name:          "London_2D",
      calculator_title:     "Create London_2D Shelves",
      calculator_tooltip:   "London_2D",
      calculator_status:    "Create shelves between two points",
      rapport_menu:         "London_2D HTML Report",
      profondeur_prompt:    "Depth (cm)",
      choix_tailles:        "Select shelf lengths",
      valider:              "Validate",
      no_component:         "No London_2D component found.",
      longueur_totale:      "Available length (cm)",
      longueur_reelle:      "Used shelf length (cm)",
      espace_restant:       "Remaining space (cm)",
      profondeur:           "Depth (cm)",
      nom:                  "Name",
      books_per_meter:      "Number of books per linear meter:",
      capacity_title:       "Capacity estimation",
      start_point_status:   "Click to place the starting point",
      end_point_status:     "Click to place the end point",
      preview_status:       "Preview displayed. Press Tab to flip, click to validate.",
      no_size_selected:     "No size selected.",
      param_dialog_title:   "Settings",
      insertion_done:       "3D insertion completed and component updated.",
      select_component:     "Select a London_2D component.",
      file_not_found:       "london_3d.skp file not found.",
      click_point_hint:     "Please click on a snap point (endpoint, midpoint, intersection).",
      dc_not_active:        "The Dynamic Components extension is not active or not initialized. The component might not update automatically.",
      book_inserter_status: "Click a component to insert the book block.",
      extension_required:   "The 'Dynamic Components' extension is required. Please activate it from the Extension Manager.",
      book_load_error:      "Error: Unable to load the book component file.",
      insert_book_command:  "Insert Book Block",
      insert_book_tooltip:  "Insert a book block into a component",
      generic_error:        "An error occurred:"
    }
  }

  def self.t(key)
    TEXTS[LANG][key] || "!!#{key}!!"
  end
end
