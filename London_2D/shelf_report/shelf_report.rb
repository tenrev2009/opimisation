require 'sketchup.rb'
require 'tempfile'

module ShelfCalculatorReport
  DICT = "London_2D"
  PANEL_THICKNESS = 3.3

  def self.generate_html
    model = Sketchup.active_model

    # Sélectionner tous les composants avec attributs London_2D
    instances = model.definitions.flat_map(&:instances).select { |i|
      i.get_attribute(DICT, "longueur_totale_cm")
    }

    if instances.empty?
      UI.messagebox("Aucun composant London_2D trouvé.")
      return
    end

    # 💬 Demander le nombre de livres par mètre linéaire
    livres_par_metre = UI.inputbox(["Nombre de livres par mètre linéaire :"], [40], "Estimation de capacité")[0].to_f
    livres_par_metre = 40 if livres_par_metre <= 0

    headers = [
      "Index", "Nom", "Longueur disponible (cm)", "Profondeur (cm)",
      "Hauteur (cm)", "Nb tablettes verticales",
      "Longueur réelle utilisée (cm)", "Espace restant (cm)",
      "Métrage linéaire (m)"
    ] + ShelfCalculator::ALL_SHELF_SIZES.map { |s| "#{s.to_i} cm" }

    rows = []
    total_ml = 0.0

    instances.each_with_index do |instance, idx|
      name = instance.name
      total = instance.get_attribute(DICT, "longueur_totale_cm").to_f
      profondeur = instance.get_attribute(DICT, "profondeur_cm").to_f
      hauteur = instance.get_attribute(DICT, "hauteur_cm").to_f
      nb_tablettes_vert = instance.get_attribute(DICT, "nb_tablettes_hauteur").to_i


      counts = {}
      longueur_etalage = 0.0
      ShelfCalculator::ALL_SHELF_SIZES.each do |size|
        key = "etagere_#{size.to_i}_cm"
        count = instance.get_attribute(DICT, key).to_i
        counts[size] = count
        longueur_etalage += count * size
      end

      longueur_reelle = (longueur_etalage + 2 * PANEL_THICKNESS).round(2)
      restant = (total - longueur_reelle).round(2)
      ml = ((longueur_etalage * nb_tablettes_vert) / 100.0).round(2)
      total_ml += ml

      row = [
        idx + 1,
        name,
        total.round(2),
        profondeur.round(2),
        hauteur.round(2),
        nb_tablettes_vert,
        longueur_reelle,
        restant,
        ml
      ] + ShelfCalculator::ALL_SHELF_SIZES.map { |s| counts[s] }

      rows << row
    end

    estimation_livres = (total_ml * livres_par_metre).to_i

    html = build_html(headers, rows, livres_par_metre, total_ml, estimation_livres)
    file = Tempfile.new(['rapport_london2d', '.html'])
    file.write(html)
    file.close
    UI.openURL("file:///" + file.path.gsub("\\", "/"))
  end

  def self.build_html(headers, rows, livres_par_metre, total_ml, estimation_total_livres)
    csv_data = ([headers] + rows).map { |row| row.join(",") }.join("\n")

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
            #{rows.map { |row| "<tr>#{row.map { |cell| "<td>#{cell}</td>" }.join}</tr>" }.join}
          </tbody>
          <tfoot>
            <tr><td colspan="#{headers.size}" style="text-align: right; font-weight: bold;">
              📚 Livres / mètre linéaire utilisé : #{livres_par_metre}
            </td></tr>
            <tr><td colspan="#{headers.size}" style="text-align: right; font-weight: bold;">
              📏 Total linéaire utilisé : #{total_ml.round(2)} m
            </td></tr>
            <tr><td colspan="#{headers.size}" style="text-align: right; font-weight: bold;">
              📘 Estimation totale de livres : #{estimation_total_livres}
            </td></tr>
          </tfoot>
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

    cmd = UI::Command.new("Rapport London_2D") {
      self.generate_html
    }
    cmd.tooltip = "Rapport London_2D"
    cmd.status_bar_text = "Afficher un rapport HTML des composants London_2D"
    cmd.large_icon = icon_path
    cmd.small_icon = icon_path

    toolbar = UI::Toolbar.new("London_2D")
    toolbar.add_item(cmd)
    toolbar.restore

    UI.menu("Plugins").add_item("Rapport HTML London_2D") {
      self.generate_html
    }

    file_loaded(__FILE__)
  end
end
