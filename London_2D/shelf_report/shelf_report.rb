# shelf_report.rb
# Plugin Rapport HTML + CSV pour London_2D (colonnes personnalisées)

require 'sketchup.rb'
require 'tempfile'

module ShelfCalculatorReport

  DICT = "London_2D"
  PANEL_THICKNESS = 3.3
  DEFAULT_BOOKS_PER_ML = 40
  ALL_SHELF_SIZES = [100.5, 90, 75, 50].freeze

  def self.generate_html
    model = Sketchup.active_model

    instances = model.definitions
                     .flat_map(&:instances)
                     .select { |i| i.get_attribute(DICT, "longueur_totale_cm") }

    if instances.empty?
      UI.messagebox("Aucun composant London_2D trouvé.", MB_OK)
      return
    end

    # En-têtes avec colonnes supplémentaires
    headers = [
      "Index", "Nom", "Profondeur (cm)", "Longueur réelle utilisée (cm)",
      "Nb tablettes", "Linéaire (ml)", "Livres/ml", "Total livres"
    ] + ALL_SHELF_SIZES.map { |s| "#{s.to_i} cm" }

    rows = []

    instances.each_with_index do |inst, idx|
      name       = inst.name.empty? ? "London_2D_#{idx+1}" : inst.name
      profondeur = inst.get_attribute(DICT, "profondeur_cm").to_f

      # Comptage par taille
      counts = {}
      used_length_per_level = 0.0
      ALL_SHELF_SIZES.each do |size|
        key = "etagere_#{size.to_i}_cm"
        cnt = inst.get_attribute(DICT, key).to_i
        counts[size] = cnt
        used_length_per_level += cnt * size
      end

      # Calcul longueur réelle utilisée (y compris panneaux)
      real_length = (used_length_per_level + 2 * PANEL_THICKNESS).round(2)

      # Nombre de tablettes verticales
      nb_tablettes = inst.get_attribute(DICT, "nb_tablettes_hauteur").to_i

      # Linéaire total = longueur par niveau * nombre de niveaux (en ml)
      total_linear_cm = used_length_per_level * nb_tablettes
      linear_ml = (total_linear_cm / 100.0).round(2)

      # Nombre de livres par ml et total livres
      books_per_ml = DEFAULT_BOOKS_PER_ML
      total_books = (linear_ml * books_per_ml).round(2)

      # Construire la ligne
      row = [
        idx+1,
        name,
        profondeur.round(2),
        real_length,
        nb_tablettes,
        linear_ml,
        books_per_ml,
        total_books
      ] + ALL_SHELF_SIZES.map { |s| counts[s] }

      rows << row
    end

    html = build_html(headers, rows)
    file = Tempfile.new(['rapport_london2d', '.html'])
    file.write(html)
    file.close
    UI.openURL("file:///" + file.path.gsub("\\", "/"))
  end

  def self.build_html(headers, rows)
    csv_data = ([headers] + rows).map { |r| r.join(",") }.join("\n")

    <<~HTML
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="utf-8">
        <title>Rapport London_2D</title>
        <style>
          body { font-family: sans-serif; padding: 20px; background: #f0f0f0; }
          table { border-collapse: collapse; width: 100%; background: white; margin-top: 20px; }
          th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: center; }
          th { background-color: #e0e0e0; }
          .btn {
            display: inline-block; padding: 10px 20px; background: #4CAF50; color: white;
            text-decoration: none; border-radius: 4px; margin-top: 10px;
          }
        </style>
      </head>
      <body>
        <h1>Rapport des étagères London_2D</h1>
        <a class="btn" href="#" onclick="exportCSV()">📄 Exporter en CSV</a>
        <table>
          <thead>
            <tr>#{headers.map { |h| "<th>#{h}</th>" }.join}</tr>
          </thead>
          <tbody>
            #{rows.map { |r| "<tr>#{r.map { |c| "<td>#{c}</td>" }.join}</tr>" }.join}
          </tbody>
        </table>
        <script>
          function exportCSV() {
            const csvContent = #{csv_data.inspect};
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement("a");
            link.setAttribute("href", url);
            link.setAttribute("download", "rapport_london2d.csv");
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
          }
        </script>
      </body>
      </html>
    HTML
  end

  unless file_loaded?(__FILE__)
    icon_path = File.join(__dir__, "icons", "london_report.png")

    cmd = UI::Command.new("Rapport London_2D") { generate_html }
    cmd.tooltip         = "Afficher le rapport HTML London_2D"
    cmd.status_bar_text = "Génère un rapport des composants London_2D"
    cmd.large_icon      = icon_path
    cmd.small_icon      = icon_path

    toolbar = UI::Toolbar.new("London_2D")
    toolbar.add_item(cmd)
    toolbar.restore

    UI.menu("Plugins").add_submenu("London_2D")
      .add_item("Rapport HTML London_2D") { generate_html }

    file_loaded(__FILE__)
  end
end
