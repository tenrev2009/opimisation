# classic_2d.rb
# Fichier lanceur principal pour l'extension London_2D
# Ce fichier doit être à la racine du dossier Plugins :
# C:/Users/jve/AppData/Roaming/SketchUp/SketchUp 2025/SketchUp/Plugins/classic_2d.rb

require 'sketchup.rb'

# Le nom du dossier principal de votre extension
EXTENSION_SUBFOLDER = "London_2D"

# Chemin de base à partir duquel les fichiers de l'extension seront chargés.
# __dir__ (ou File.dirname(__FILE__)) est le dossier où se trouve classic_2d.rb (Plugins/)
# On ajoute le nom du sous-dossier de l'extension.
PATH_TO_EXTENSION_ROOT = File.join(__dir__, EXTENSION_SUBFOLDER)

# Ajout du dossier racine de l'extension et de ses sous-dossiers au $LOAD_PATH
# Cela permet d'utiliser des 'require' plus simples par la suite si nécessaire,
# bien que l'utilisation de chemins complets avec File.join soit plus robuste.
$LOAD_PATH.unshift(PATH_TO_EXTENSION_ROOT) unless $LOAD_PATH.include?(PATH_TO_EXTENSION_ROOT)

# On pourrait aussi ajouter chaque sous-dossier au $LOAD_PATH si on voulait faire des 
# require 'book_inserter.rb' directement, mais c'est optionnel et peut prêter à confusion.
# $LOAD_PATH.unshift(File.join(PATH_TO_EXTENSION_ROOT, 'book_inserter'))
# ... etc pour chaque sous-dossier ...


# --- Chargement des modules de l'extension ---
# Chaque require utilise PATH_TO_EXTENSION_ROOT comme base.

begin
  puts "Chargement de London2D depuis: #{PATH_TO_EXTENSION_ROOT}"

  # 1. Modules existants (dans leurs sous-dossiers de London_2D/)
  require File.join(PATH_TO_EXTENSION_ROOT, 'shelf_calculator', 'shelf_calculator.rb')
  require File.join(PATH_TO_EXTENSION_ROOT, 'shelf_report',     'shelf_report.rb')
  require File.join(PATH_TO_EXTENSION_ROOT, 'dynamic_3d',       'inject_3d.rb')
  require File.join(PATH_TO_EXTENSION_ROOT, 'book_inserter',    'book_inserter.rb')
  require File.join(PATH_TO_EXTENSION_ROOT, 'sub_component_deleter.rb') 
  
  # Pour l'outil d'insertion de bacs (s'il est dans son propre sous-dossier de London_2D/)
  # Assurez-vous que le chemin est correct si vous l'avez créé.
  # S'il n'existe pas encore ou que vous ne l'utilisez pas, commentez la ligne.
  require File.join(PATH_TO_EXTENSION_ROOT, 'bac_inserter',    'bac_inserter.rb')

  # 2. Nouveaux outils (directement dans le dossier London_2D/)
  # Ces fichiers sont supposés être directement dans le dossier London_2D/
  require File.join(PATH_TO_EXTENSION_ROOT, 'dc_redraw_tool.rb')
  require File.join(PATH_TO_EXTENSION_ROOT, 'dc_options_tool.rb')

  puts "Tous les modules de London2D ont été chargés."

rescue LoadError => e
  # Afficher un message d'erreur plus détaillé si un fichier est introuvable
  UI.messagebox("Erreur au chargement d'un module de l'extension London2D:\n#{e.message}\nChemin de base tenté: #{PATH_TO_EXTENSION_ROOT}\nVérifiez l'arborescence des fichiers et les noms.")
rescue => e # Attrape d'autres erreurs potentielles pendant le chargement initial
  UI.messagebox("Une erreur inattendue est survenue lors du chargement de l'extension London2D:\n#{e.message}\n#{e.backtrace.join("\n")}")
end

# Le module London2D est défini dans chaque fichier d'outil.
# Il n'est pas nécessaire de le définir ici si classic_2d.rb ne fait que charger.
# Si vous voulez un point central pour des constantes ou méthodes partagées par TOUS
# les outils, vous pourriez le faire ici.

# Exemple de vérification (optionnel)
# if defined?(London2D::BookInserter)
#   puts "Module BookInserter chargé."
# else
#   puts "ATTENTION : Module BookInserter NON chargé."
# end

