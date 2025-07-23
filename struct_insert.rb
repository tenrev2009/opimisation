module JACKCOMPONENT
  ROOT             = File.dirname(__FILE__)
  COMPONENTS_PATH  = File.join(ROOT, 'Components')
  RESOURCES_PATH   = File.join(ROOT, 'Resources')
  COMPONENT_FILES  = {
    'Structure SF'       => '01-SF.skp',
    'Structure DF'       => '02-DF.skp',
    'DF Départ'          => '03-DF DEPART.skp'
  }
  
  class << self
    def add(label)
      filename = COMPONENT_FILES[label]
      path     = File.join(COMPONENTS_PATH, filename)
      unless File.exist?(path)
        UI.messagebox("Fichier introuvable : #{filename}")
        return
      end
      Sketchup.active_model.import(path)
    end
  end

  unless file_loaded?(__FILE__)
    menu    = UI.menu('Plugins').add_submenu('London_2d')
    toolbar = UI::Toolbar.new('London_2d')

    COMPONENT_FILES.each_key do |label|
      command = UI::Command.new(label) { JACKCOMPONENT.add(label) }
      icon    = File.join(RESOURCES_PATH, "add_#{label.downcase.gsub(/\s+/, '_')}.png")
      command.small_icon      = icon
      command.large_icon      = icon
      command.tooltip         = label
      command.status_bar_text = label
      command.menu_text       = label
      menu.add_item(command)
      toolbar.add_item(command)
    end

    toolbar.restore
    file_loaded(__FILE__)
  end
end
