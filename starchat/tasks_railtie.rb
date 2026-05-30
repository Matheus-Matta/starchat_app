# frozen_string_literal: true

class TasksRailtie < Rails::Railtie
  rake_tasks do
    # Load all rake tasks from starchat/lib/tasks
    Dir.glob(Rails.root.join('starchat/lib/tasks/**/*.rake')).each { |f| load f }
  end
end
