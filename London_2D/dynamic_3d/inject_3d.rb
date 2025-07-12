# inject_3d.rb
# Module London2D::Dynamic3D – Outil interactif d’insertion et mise à jour du composant 3D

require 'sketchup.rb'

module London2D
  module Dynamic3D

    DICT = "London_2D"
    SHELF_ATTRS = {
      100.5 => "etagere_100_cm",
      90    => "etagere_90_cm",
      75    => "etagere_75_cm",
      50    => "etagere_50_cm"
    }

    #
    # Outil interactif : click Point1, click Point2, preview + Tab pour inverser, click pour valider
    #
    class ComponentPlacement3DTool
      def initialize(definition, shelf_counts, nb_tablettes, hauteur_pouces)
        @definition    = definition
        @counts        = shelf_counts
        @nb_tablettes  = nb_tablettes
        @hauteur       = hauteur_pouces
        @ip            = Sketchup::InputPoint.new
        @step          = 0
        @first_pt      = nil
        @second_pt     = nil
        @reverse       = false
        @view          = Sketchup.active_model.active_view
      end

      def activate
        Sketchup.status_text = "Cliquez pour définir Point 1"
        @view.invalidate
      end

      def deactivate(view)
        view.invalidate
        Sketchup.status_text = ""
      end

      def onMouseMove(flags, x, y, view)
        @ip.pick(view, x, y)
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.valid?

        case @step
        when 1
          view.drawing_color = 'red'; view.line_width = 4
          view.draw_points(@first_pt, 10, 1)
        when 2
          view.drawing_color = 'red';   view.line_width = 4
          view.draw_points(@first_pt, 10, 1)
          view.drawing_color = 'green'; view.line_width = 4
          view.draw_points(@second_pt, 8, 1)
          view.drawing_color = 'blue';  view.line_width = 2
          view.draw_lines(@first_pt, @second_pt)
          draw_preview_bbox(view)
        end
      end

      def onKeyDown(key, repeat, flags, view)
        if key == 9 && @step == 2  # Tab
          @reverse = !@reverse
          view.invalidate
        end
      end

      def onLButtonDown(flags, x, y, view)
        @ip.pick(view, x, y)
        return unless @ip.valid?

        case @step
        when 0
          @first_pt = @ip.position
          @step = 1
          Sketchup.status_text = "Cliquez pour définir Point 2"
        when 1
          @second_pt = @ip.position
          @step = 2
          Sketchup.status_text = "Aperçu : Tab pour inverser, clic pour valider"
        when 2
          place_and_finish
        end
      end

      private

      # preview du bounding box du composant 3D transformé
      def draw_preview_bbox(view)
        t = axes_transform
        bbox = @definition.bounds
        corners = (0..7).map { |i| bbox.corner(i).transform(t) }
        view.drawing_color = 'gray'; view.line_width = 1
        view.draw(GL_LINE_LOOP, corners[0], corners[1], corners[3], corners[2])
        view.draw(GL_LINE_LOOP, corners[4], corners[5], corners[7], corners[6])
        view.draw(GL_LINES,
          corners[0], corners[4],
          corners[1], corners[5],
          corners[2], corners[6],
          corners[3], corners[7]
        )
      end

      # insère le composant final, injecte attributs, met à jour DC
      def place_and_finish
        model = Sketchup.active_model
        model.start_operation("Insérer module 3D dynamique", true)
        comp = model.active_entities.add_instance(@definition, axes_transform)

        da = "dynamic_attributes"
        comp.set_attribute(da, "nb_100",      @counts[100.5])
        comp.set_attribute(da, "nb_90",       @counts[90])
        comp.set_attribute(da, "nb_75",       @counts[75])
        comp.set_attribute(da, "nb_50",       @counts[50])
        comp.set_attribute(da, "nb_tablette", @nb_tablettes)
        comp.set_attribute(da, "hauteur",     @hauteur)

        if defined?($dc_observers) && $dc_observers.get_latest_class
          $dc_observers.get_latest_class.redraw_with_undo(comp)
        elsif defined?(Sketchup::DynamicComponents::Tools)
          Sketchup::DynamicComponents::Tools.update_attributes(comp)
        end
        comp.dynamic_attributes_updated if comp.respond_to?(:dynamic_attributes_updated)

        Dynamic3D.update_children_dynamic(comp, @counts, @nb_tablettes, @hauteur)

        model.commit_operation
        model.active_view.refresh
        Sketchup.status_text = "Module 3D inséré"
        Sketchup.active_model.tools.pop_tool
      end

      # calcule la transformation axes + réflexion appliquée APRES axes
      def axes_transform
        xaxis = @first_pt.vector_to(@second_pt).normalize
        zaxis = Z_AXIS
        yaxis = zaxis * xaxis
        t = Geom::Transformation.axes(@first_pt, xaxis, yaxis, xaxis * yaxis)
        return t unless @reverse
        # plan de symétrie : contenant P1→P2 et Z
        plane_normal = xaxis.cross(Z_AXIS)
        refl = Geom::Transformation.reflection([@first_pt, plane_normal])
        t * refl  # on applique la réflexion APRÈS la transformation axes
      end
    end

    # démarrage de l’outil interactif 3D
    def self.start_3d_tool
      model = Sketchup.active_model
      sel = model.selection.grep(Sketchup::ComponentInstance)
                  .select { |i| i.get_attribute(DICT, "point1_world") && i.get_attribute(DICT, "point2_world") }
      unless sel.any?
        UI.messagebox("Sélectionnez un module 2D London_2D déjà créé.", MB_OK)
        return
      end
      inst = sel.first
      counts = {}; SHELF_ATTRS.each { |l,a| counts[l] = inst.get_attribute(DICT,a).to_i }
      nb_tab = inst.get_attribute(DICT,"nb_tablettes_hauteur").to_i
      haut_cm = inst.get_attribute(DICT,"hauteur_cm").to_f
      haut_in = (haut_cm/2.54).round(2)

      skp3d = File.join(__dir__,"london_3d.skp")
      unless File.exist?(skp3d)
        UI.messagebox("london_3d.skp introuvable.", MB_OK)
        return
      end
      def3d = model.definitions.load(skp3d)
      tool = ComponentPlacement3DTool.new(def3d, counts, nb_tab, haut_in)
      model.tools.push_tool(tool)
    end

    def self.update_children_dynamic(parent, counts, nb_tab, hauteur)
      da = "dynamic_attributes"
      parent.definition.entities.grep(Sketchup::ComponentInstance).each do |ch|
        next unless ch.attribute_dictionaries&.key?(da)
        ch.set_attribute(da,"nb_100",counts[100.5])
        ch.set_attribute(da,"nb_90", counts[90])
        ch.set_attribute(da,"nb_75", counts[75])
        ch.set_attribute(da,"nb_50", counts[50])
        ch.set_attribute(da,"nb_tablette",nb_tab)
        ch.set_attribute(da,"hauteur",hauteur)
      end
    end

    unless file_loaded?(__FILE__)
      icon = File.join(__dir__,"icons","london_3d.png")
      cmd = UI::Command.new("3D interactif") { start_3d_tool }
      cmd.tooltip = "Insertion 3D interactive London_2D"
      cmd.status_bar_text = "Point1→Point2→validate"
      cmd.large_icon = cmd.small_icon = icon
      toolbar = UI::Toolbar.new("London_2D")
      toolbar.add_item(cmd)
      toolbar.restore
      UI.menu("Plugins").add_submenu("London_2D").add_item("3D interactif") { start_3d_tool }
      file_loaded(__FILE__)
    end

  end
end


