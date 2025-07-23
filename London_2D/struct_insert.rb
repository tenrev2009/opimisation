module JACKCOMPONENT
  ROOT             = __dir__
  COMPONENTS_PATH  = File.join(ROOT, 'Composants')
  RESOURCES_PATH   = File.join(ROOT, 'Ressources')
  COMPONENT_FILES  = {
    'Structure DF' => 'DF.skp',
    'Structure SF' => 'SF.skp',
    'TABLE'        => 'TABLE.skp'
  }

  class << self
    def add(label)
      filename = COMPONENT_FILES[label]
      path     = File.join(COMPONENTS_PATH, filename)
      # DEBUG : décommentez pour voir le chemin
      # UI.messagebox("Import depuis : #{path}")
      unless File.exist?(path)
        UI.messagebox("Fichier introuvable :\n#{path}")
        return
      end
      Sketchup.active_model.import(path)
    end
  end

  unless file_loaded?(__FILE__)
    menu    = UI.menu('Plugins').add_submenu('London_2D')
    toolbar = UI::Toolbar.new('London_2D')

    COMPONENT_FILES.each_key do |label|
      cmd  = UI::Command.new(label) { JACKCOMPONENT.add(label) }
      icon = File.join(RESOURCES_PATH, "add_#{label.downcase.gsub(/\s+/, '_')}.png")
      unless File.exist?(icon)
        UI.messagebox("Icône introuvable :\n#{icon}")
      end
      [ :small_icon, :large_icon ].each { |sym| cmd.send("#{sym}=", icon) }
      cmd.tooltip         = label
      cmd.status_bar_text = label
      cmd.menu_text       = label
      menu.add_item(cmd)
      toolbar.add_item(cmd)
    end

    toolbar.restore
    file_loaded(__FILE__)
  end
end
