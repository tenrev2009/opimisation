# shelf_calculator.rb
# Module London2D – Calculateur et insertion 2D d’étagères

require 'sketchup.rb'

module London2D
  ALL_SHELF_SIZES = [100.5, 90, 75, 50].freeze   # longueurs disponibles en cm
  PANEL_THICKNESS = 3.3.cm                        # épaisseur des montants

  #------------------------------
  # Optimiseur de découpe
  #------------------------------
  class ShelfOptimizer
    def self.calculate_shelves(usable_length_cm, sizes)
      best = { shelves: [], remaining_length: Float::INFINITY }
      uniq = sizes.compact.uniq.sort.reverse
      try_combinations(usable_length_cm, uniq, [], 0, best, usable_length_cm)
      best
    end

    def self.try_combinations(remaining, sizes, current, idx, best, total)
      if remaining >= 0 && !current.empty?
        used = current.sum { |e| e[:length] * e[:count] }
        rem  = (total - used).abs
        if rem < best[:remaining_length]
          best[:shelves] = current.dup
          best[:remaining_length] = rem
        end
      end
      sizes.each_with_index do |sz, i|
        next if i < idx || sz > remaining
        (remaining / sz).floor.downto(1) do |c|
          try_combinations(remaining - sz*c, sizes,
                           current + [{ length: sz, count: c }],
                           i+1, best, total)
        end
      end
    end
  end  # class ShelfOptimizer

  #------------------------------
  # Outil principal
  #------------------------------
  class ShelfCalculatorTool
    def activate
      reset_state
      Sketchup.status_text = "Cliquez pour placer le point de départ"
    end

    def onMouseMove(_flags, x, y, view)
      @ip.pick(view, x, y)
      view.invalidate
    end

    def draw(view)
      @ip.draw(view) if @ip.valid?
      return unless @step == 2
      t = axes_from(@pt1, @pt2, @reverse)
      view.drawing_color = Sketchup::Color.new(194,149,107,180)
      draw_geometry(view, t, @solution, @depth)
    end

    def onKeyDown(key, _r, _f, view)
      # Tab (9) inverse le sens
      if key == 9 && @step == 2
        @reverse = !@reverse
        view.invalidate
      end
    end

    def onLButtonDown(_flags, x, y, view)
      @ip.pick(view, x, y)
      return unless @ip.valid?
      case @step
      when 0
        @pt1 = @ip.position
        @step = 1
        Sketchup.status_text = "Cliquez pour placer le point d'arrivée"
      when 1
        @pt2 = @ip.position
        dist = @pt1.distance(@pt2).to_cm.round(2)
        return if dist < 1
        ask_params_and_open_dialog(dist)
      when 2
        create_component
      end
    end

    private

    def reset_state
      @step = 0
      @pt1 = @pt2 = nil
      @reverse = false
      @solution = nil
      @depth = @height = @columns = nil
      @ip = Sketchup::InputPoint.new
    end

    def ask_params_and_open_dialog(total_cm)
      prompts = ["Profondeur (cm)", "Hauteur (cm)", "Nb tablettes verticales"]
      defs    = ["30","180","5"]
      inb     = UI.inputbox(prompts, defs, "Paramètres")
      return unless inb
      @depth, @height, @columns = inb[0].to_f, inb[1].to_f, inb[2].to_i

      dlg = UI::HtmlDialog.new(
        dialog_title:    "Choix des longueurs",
        preferences_key: "shelf_sizes_dialog",
        scrollable:      false,
        resizable:       false,
        width:           400,
        height:          300
      )
      dlg.set_file(File.join(__dir__, "shelf_sizes_dialog.html"))
      dlg.add_action_callback("on_submit") do |_, sizes|
        arr = sizes.split(',').map(&:to_f)
        if arr.empty?
          UI.messagebox("Aucune taille sélectionnée."); next
        end
        usable = total_cm - 2*(PANEL_THICKNESS/1.cm)
        @solution = ShelfOptimizer.calculate_shelves(usable, arr)
        @step = 2
        Sketchup.status_text = "Aperçu affiché – Tab pour inverser, clic pour valider"
        Sketchup.active_model.active_view.invalidate
        dlg.close
      end
      dlg.show
    end

    def create_component
      return unless @step == 2
      model = Sketchup.active_model
      model.start_operation("Créer étagères 2D", true)

      defn = model.definitions.add("London_2D")
      grp  = defn.entities.add_group
      mat  = model.materials["Bois clair"] || model.materials.add("Bois clair")
      mat.color = Sketchup::Color.new(194,149,107)

      build_group(grp, @pt1, @pt2, @solution, @depth, mat, @reverse)

      inst = model.active_entities.add_instance(defn,
        axes_from(@pt1, @pt2, @reverse)
      )
      inst.name = "London_2D_#{model.entities.grep(Sketchup::ComponentInstance).size}"
      store_attributes(inst)

      model.commit_operation
      reset_state
      Sketchup.status_text = "Cliquez pour placer le point de départ"
    end

    def draw_geometry(view, t, sol, depth_cm)
      draw_proc = ->(pts) { view.draw(GL_POLYGON, *pts.map{ |p| p.transform(t) }) }
      draw_sequence(draw_proc, sol, depth_cm)
    end

    def build_group(group, p1, p2, sol, depth_cm, material, reverse)
      draw_proc = ->(pts){ f = group.entities.add_face(pts); f.material = f.back_material = material }
      draw_sequence(draw_proc, sol, depth_cm)
    end

    def draw_sequence(draw_proc, sol, depth_cm)
      base = ORIGIN
      pts = [
        base,
        base.offset(X_AXIS,PANEL_THICKNESS),
        base.offset(X_AXIS,PANEL_THICKNESS).offset(Y_AXIS,depth_cm.cm),
        base.offset(Y_AXIS,depth_cm.cm)
      ]
      draw_proc.call(pts)
      pos = PANEL_THICKNESS
      sol[:shelves].each do |s|
        s[:count].times do
          len = s[:length].cm
          o   = ORIGIN.offset(X_AXIS,pos)
          pts = [ o, o.offset(X_AXIS,len), o.offset(X_AXIS,len).offset(Y_AXIS,depth_cm.cm), o.offset(Y_AXIS,depth_cm.cm) ]
          draw_proc.call(pts)
          pos += len
        end
      end
      o = ORIGIN.offset(X_AXIS,pos)
      pts = [ o, o.offset(X_AXIS,PANEL_THICKNESS), o.offset(X_AXIS,PANEL_THICKNESS).offset(Y_AXIS,depth_cm.cm), o.offset(Y_AXIS,depth_cm.cm) ]
      draw_proc.call(pts)
    end

    def axes_from(p1,p2,rev)
      x = p1.vector_to(p2).normalize
      y = Z_AXIS * x; y.reverse! if rev
      z2 = x * y
      Geom::Transformation.axes(p1, x, y, z2)
    end

    def store_attributes(inst)
      inst.set_attribute("London_2D","point1_world",      @pt1.to_a)
      inst.set_attribute("London_2D","point2_world",      @pt2.to_a)
      inst.set_attribute("London_2D","longueur_totale_cm",(@pt1.distance(@pt2)).to_cm.round(2))
      inst.set_attribute("London_2D","profondeur_cm",     @depth)
      inst.set_attribute("London_2D","hauteur_cm",        @height)
      inst.set_attribute("London_2D","nb_tablettes_hauteur",@columns)
      @solution[:shelves].each do |s|
        inst.set_attribute("London_2D","etagere_#{s[:length].to_i}_cm", s[:count])
      end
    end

    # Édition en place
    def self.open_edit_dialog_for(inst)
      dict = inst.attribute_dictionary("London_2D", true)
      pt1  = Geom::Point3d.new(*dict["point1_world"])
      pt2  = Geom::Point3d.new(*dict["point2_world"])
      depth  = dict["profondeur_cm"]
      height = dict["hauteur_cm"]
      cols   = dict["nb_tablettes_hauteur"]
      reverse= dict["reverse_side"] || false
      existing = ALL_SHELF_SIZES.map{|sz| "#{sz}:#{dict["etagere_#{sz.to_i}_cm"]||0}"}.join(',')

      dlg = UI::HtmlDialog.new(
        dialog_title:    "Éditer étagères",
        preferences_key: "edit_shelf_dialog",
        scrollable:      true,
        resizable:       true,
        width:           500,
        height:          550
      )
      dlg.set_file(File.join(__dir__,"edit_shelf.html"))

      dlg.add_action_callback("initialize") do
        dlg.execute_script("init(#{depth}, #{height}, #{cols}, '#{existing}')")
      end

      dlg.add_action_callback("on_submit_edit") do |_, data|
        new_depth  = data["depth"].to_f
        new_height = data["height"].to_f
        new_cols   = data["cols"].to_i
        arr = data["lengths"].split(',').map{|v|l,c=v.split(':');[l.to_f,c.to_i]}
        sol = { shelves: arr.reject{|_,c|c.zero?}.map{|l,c|{length:l,count:c}} }

        inst.set_attribute("London_2D","profondeur_cm", new_depth)
        inst.set_attribute("London_2D","hauteur_cm",   new_height)
        inst.set_attribute("London_2D","nb_tablettes_hauteur", new_cols)
        arr.each{|l,c| inst.set_attribute("London_2D","etagere_#{l.to_i}_cm", c)}

        comp_def = inst.definition
        grp      = comp_def.entities.grep(Sketchup::Group).first
        grp.entities.clear!

        mat = inst.material || Sketchup.active_model.materials["Bois clair"]
        mat.color ||= Sketchup::Color.new(194,149,107)
        tool = ShelfCalculatorTool.new
        tool.send(:build_group, grp, pt1, pt2, sol, new_depth, mat, reverse)

        dlg.close
        Sketchup.active_model.active_view.refresh
      end

      dlg.show
    end
  end  # class ShelfCalculatorTool

  unless file_loaded?(__FILE__)
    icon = File.join(__dir__, "icons", "london_2d.png")
    toolbar = UI::Toolbar.new("London_2D")
    cmd = UI::Command.new("London_2D"){ Sketchup.active_model.select_tool(ShelfCalculatorTool.new) }
    cmd.tooltip    = "Créer des étagères London_2D"
    cmd.large_icon = cmd.small_icon = icon
    toolbar.add_item(cmd)
    toolbar.restore

    UI.menu("Plugins").add_item("London_2D"){ Sketchup.active_model.select_tool(ShelfCalculatorTool.new) }

    UI.add_context_menu_handler do |menu|
      sel = Sketchup.active_model.selection.first
      if sel.is_a?(Sketchup::ComponentInstance) && sel.definition.name.start_with?("London_2D")
        menu.add_item("Modifier étagères"){ ShelfCalculatorTool.open_edit_dialog_for(sel) }
      end
    end

    file_loaded(__FILE__)
  end

end  # module London2D

