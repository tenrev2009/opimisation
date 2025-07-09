# shelf_calculator.rb
# Module London2D – Calculateur et insertion 2D d’étagères

require 'sketchup.rb'

module London2D
  ALL_SHELF_SIZES   = [100.5, 90, 75, 50].freeze   # longueurs disponibles en cm
  PANEL_THICKNESS   = 3.3.cm                        # épaisseur des montants

  #
  # Calcule la meilleure combinaison d'étagères pour optimiser l'usage de la longueur utile
  #
  class ShelfOptimizer
    def self.calculate_shelves(usable_length_cm, shelf_sizes)
      best = { shelves: [], total_length: 0, remaining_length: Float::INFINITY }
      sizes = shelf_sizes.compact.uniq.sort.reverse
      try_combinations(usable_length_cm, sizes, [], 0, best, usable_length_cm)
      best
    end

    def self.try_combinations(remaining, sizes, current, idx, best, total)
      if remaining >= 0 && !current.empty?
        used = current.sum { |s| s[:length] * s[:count] }
        rem  = (total - used).abs
        if rem < best[:remaining_length]
          best[:shelves]          = current.dup
          best[:total_length]     = used
          best[:remaining_length] = rem
        end
      end
      sizes.each_with_index do |sz, i|
        next if i < idx || sz > remaining
        max_c = (remaining / sz).floor
        max_c.downto(1) do |c|
          try_combinations(remaining - sz*c, sizes,
                           current + [{ length: sz, count: c }],
                           i + 1, best, total)
        end
      end
    end
  end

  #
  # Outil SketchUp : sélection de deux points, aperçu, puis création 2D des étagères
  #
  class ShelfCalculatorTool
    def activate
      @step         = 0
      @first_point  = nil
      @second_point = nil
      @reverse_side = false
      @solution     = nil
      @depth_cm     = nil
      @height_cm    = nil
      @columns      = nil
      @ip           = Sketchup::InputPoint.new
      Sketchup.status_text = "Cliquez pour placer le point de départ"
    end

    def onMouseMove(flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip.valid?
      return unless @step == 2 && @first_point && @second_point && @solution

      t = axes_from(@first_point, @second_point, @reverse_side)
      view.drawing_color = Sketchup::Color.new(194,149,107,180)

      # Montant gauche
      pts = [
        ORIGIN,
        ORIGIN.offset(X_AXIS, PANEL_THICKNESS),
        ORIGIN.offset(X_AXIS, PANEL_THICKNESS).offset(Y_AXIS, @depth_cm.cm),
        ORIGIN.offset(Y_AXIS, @depth_cm.cm)
      ]
      view.draw(GL_POLYGON, *pts.map { |p| p.transform(t) })

      # Tablettes
      pos_x = PANEL_THICKNESS
      @solution[:shelves].each do |s|
        s[:count].times do
          len = s[:length].cm
          pts = [
            ORIGIN.offset(X_AXIS, pos_x),
            ORIGIN.offset(X_AXIS, pos_x + len),
            ORIGIN.offset(X_AXIS, pos_x + len).offset(Y_AXIS, @depth_cm.cm),
            ORIGIN.offset(X_AXIS, pos_x).offset(Y_AXIS, @depth_cm.cm)
          ]
          view.draw(GL_POLYGON, *pts.map { |p| p.transform(t) })
          pos_x += len
        end
      end

      # Montant droit
      pts = [
        ORIGIN.offset(X_AXIS, pos_x),
        ORIGIN.offset(X_AXIS, pos_x + PANEL_THICKNESS),
        ORIGIN.offset(X_AXIS, pos_x + PANEL_THICKNESS).offset(Y_AXIS, @depth_cm.cm),
        ORIGIN.offset(X_AXIS, pos_x).offset(Y_AXIS, @depth_cm.cm)
      ]
      view.draw(GL_POLYGON, *pts.map { |p| p.transform(t) })
    end

    def onKeyDown(key, repeat, flags, view)
      if key == 9 && @step == 2  # Tabulation
        @reverse_side = !@reverse_side
        view.invalidate
      end
    end

    def onLButtonDown(flags, x, y, view)
      @ip.pick(view, x, y)
      return unless @ip.valid?

      case @step
      when 0
        @first_point = @ip.position
        @step = 1
        Sketchup.status_text = "Cliquez pour placer le point d'arrivée"
      when 1
        @second_point = @ip.position
        dist_cm = @second_point.distance(@first_point).to_cm.round(2)
        return if dist_cm < 1

        prompts  = ["Profondeur (cm)", "Hauteur (cm)", "Nb tablettes verticales"]
        defaults = ["30", "200", "5"]
        input    = UI.inputbox(prompts, defaults, "Paramètres d'étagères")
        return unless input

        @depth_cm  = input[0].to_f
        @height_cm = input[1].to_f
        @columns   = input[2].to_i

        open_html_dialog(dist_cm)
      when 2
        create_component
      end
    end

    def open_html_dialog(total_cm)
      path = File.join(__dir__, "shelf_sizes_dialog.html")
      dlg = UI::HtmlDialog.new(
        dialog_title:    "Choix des longueurs",
        preferences_key: "shelf_sizes_dialog",
        scrollable:      false,
        resizable:       false,
        width:           400,
        height:          300,
        style:           UI::HtmlDialog::STYLE_DIALOG
      )
      dlg.set_file(path)
      dlg.add_action_callback("on_submit") do |_, sizes|
        arr = sizes.split(',').map(&:to_f)
        if arr.empty?
          UI.messagebox("Aucune taille sélectionnée.")
          next
        end
        usable = total_cm - 2 * (PANEL_THICKNESS / 1.cm)
        @solution = ShelfOptimizer.calculate_shelves(usable, arr)
        @step = 2
        Sketchup.status_text = "Aperçu affiché – Tab pour inverser, clic pour valider"
        Sketchup.active_model.active_view.invalidate
        dlg.close
      end
      dlg.show
    end

    def create_component
      return unless @first_point && @second_point && @solution

      t = axes_from(@first_point, @second_point, @reverse_side)
      model = Sketchup.active_model
      model.start_operation("Créer étagères 2D", true)

      # Définition et groupe 2D
      def2d = model.definitions.add("London_2D")
      grp2d = def2d.entities.add_group
      ents  = grp2d.entities

      mat = model.materials["Bois clair"] || model.materials.add("Bois clair")
      mat.color = Sketchup::Color.new(194,149,107)

      # Montant gauche
      pts = [
        ORIGIN,
        ORIGIN.offset(X_AXIS, PANEL_THICKNESS),
        ORIGIN.offset(X_AXIS, PANEL_THICKNESS).offset(Y_AXIS, @depth_cm.cm),
        ORIGIN.offset(Y_AXIS, @depth_cm.cm)
      ]
      f = ents.add_face(pts); f.material = f.back_material = mat

      # Tablettes
      pos_x = PANEL_THICKNESS
      @solution[:shelves].each do |s|
        s[:count].times do
          len = s[:length].cm
          pts = [
            ORIGIN.offset(X_AXIS, pos_x),
            ORIGIN.offset(X_AXIS, pos_x + len),
            ORIGIN.offset(X_AXIS, pos_x + len).offset(Y_AXIS, @depth_cm.cm),
            ORIGIN.offset(X_AXIS, pos_x).offset(Y_AXIS, @depth_cm.cm)
          ]
          f = ents.add_face(pts); f.material = f.back_material = mat
          pos_x += len
        end
      end

      # Montant droit
      pts = [
        ORIGIN.offset(X_AXIS, pos_x),
        ORIGIN.offset(X_AXIS, pos_x + PANEL_THICKNESS),
        ORIGIN.offset(X_AXIS, pos_x + PANEL_THICKNESS).offset(Y_AXIS, @depth_cm.cm),
        ORIGIN.offset(X_AXIS, pos_x).offset(Y_AXIS, @depth_cm.cm)
      ]
      f = ents.add_face(pts); f.material = f.back_material = mat

      # Création de l'instance 2D
      inst2d = model.active_entities.add_instance(def2d, t)
      inst2d.name = "London_2D_#{model.entities.grep(Sketchup::ComponentInstance).count}"

      # Stockage des deux points
      inst2d.set_attribute("London_2D", "point1_world", @first_point.to_a)
      inst2d.set_attribute("London_2D", "point2_world", @second_point.to_a)

      # Attributs
      inst2d.set_attribute("London_2D", "longueur_totale_cm", (@second_point.distance(@first_point)).to_cm.round(2))
      inst2d.set_attribute("London_2D", "profondeur_cm",       @depth_cm.round(2))
      inst2d.set_attribute("London_2D", "hauteur_cm",          @height_cm.round(2))
      inst2d.set_attribute("London_2D", "nb_tablettes_hauteur",@columns)
      @solution[:shelves].each do |s|
        key = "etagere_#{s[:length].to_i}_cm"
        inst2d.set_attribute("London_2D", key, s[:count])
      end

      model.commit_operation
      reset_tool
    end

    def reset_tool
      @step         = 0
      @first_point  = @second_point = nil
      @solution     = nil
      Sketchup.status_text = "Cliquez pour placer le point de départ"
    end

    private

    # Retourne la transformation axes
    def axes_from(p1, p2, rev)
      x = p1.vector_to(p2).normalize
      z = Z_AXIS
      y = z * x
      y.reverse! if rev
      z2 = x * y
      Geom::Transformation.axes(p1, x, y, z2)
    end
  end

  unless file_loaded?(__FILE__)
    icon = File.join(__dir__, "icons", "london_2d.png")
    toolbar = UI::Toolbar.new("London_2D")
    cmd     = UI::Command.new("London_2D") { Sketchup.active_model.select_tool(ShelfCalculatorTool.new) }
    cmd.tooltip         = "Créer des étagères London_2D"
    cmd.status_bar_text = "Dessinez un ensemble d'étagères"
    cmd.large_icon      = icon
    cmd.small_icon      = icon
    toolbar.add_item(cmd)
    toolbar.restore

    UI.menu("Plugins").add_item("London_2D") { Sketchup.active_model.select_tool(ShelfCalculatorTool.new) }
    file_loaded(__FILE__)
  end
end


