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
      nom:                  "Nom"
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
      nom:                  "Name"
    }
  }

  def self.t(key)
    TEXTS[LANG][key] || "!!#{key}!!"
  end
end
