# frozen_string_literal: true

require 'rails/railtie'

module Importmap
  module Node
    class Railtie < Rails::Railtie
      railtie_name :importmap_node

      rake_tasks do
        load File.join(__dir__, '..', '..', 'tasks', 'importmap_node.rake')
      end
    end
  end
end
