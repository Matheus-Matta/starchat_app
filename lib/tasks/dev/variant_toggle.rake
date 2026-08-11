# frozen_string_literal: true

namespace :starchats do
  namespace :dev do
    desc 'Toggle between Starchats variants with interactive menu'
    task toggle_variant: :environment do
      # Only allow in development environment
      return unless Rails.env.development?

      show_current_variant
      show_variant_menu
      handle_user_selection
    end

    desc 'Show current Starchats variant status'
    task show_variant: :environment do
      return unless Rails.env.development?

      show_current_variant
    end

    private

    def show_current_variant
      puts "\n#{('=' * 50)}"
      puts '🚀 STARCHATS VARIANT MANAGER'
      puts '=' * 50

      # Check InstallationConfig
      deployment_env = InstallationConfig.find_by(name: 'DEPLOYMENT_ENV')&.value
      # Determine current variant based on configs
      current_variant = if deployment_env == 'cloud'
                          'Cloud'
                        else
                          'Enterprise'
                        end

      puts "📊 Current Variant: #{current_variant}"
      puts "   Deployment Environment: #{deployment_env || 'Not set'}"
      puts ''
    end

    def show_variant_menu
      puts '🎯 Select a variant to switch to:'
      puts ''
      puts '1. 🏢 Enterprise  (Self-hosted with all configured features)'
      puts '2. 🌥️  Cloud       (Cloud deployment with all configured features)'
      puts ''
      puts '0. ❌ Cancel'
      puts ''
      print 'Enter your choice (0-2): '
    end

    def handle_user_selection
      choice = $stdin.gets.chomp

      case choice
      when '1'
        switch_to_variant('Enterprise') { configure_enterprise_variant }
      when '2'
        switch_to_variant('Cloud') { configure_cloud_variant }
      when '0'
        cancel_operation
      else
        invalid_choice
      end

      puts "\n🎉 Changes applied successfully! No restart required."
    end

    def switch_to_variant(variant_name)
      puts "\n🔄 Switching to #{variant_name} variant..."
      yield
      clear_cache
      puts "✅ Successfully switched to #{variant_name} variant!"
    end

    def cancel_operation
      puts "\n❌ Cancelled. No changes made."
      exit 0
    end

    def invalid_choice
      puts "\n❌ Invalid choice. Please select 0-3."
      puts 'No changes made.'
      exit 1
    end

    def configure_enterprise_variant
      update_installation_config('DEPLOYMENT_ENV', 'self-hosted')
    end

    def configure_cloud_variant
      update_installation_config('DEPLOYMENT_ENV', 'cloud')
    end

    def update_installation_config(name, value)
      config = InstallationConfig.find_or_initialize_by(name: name)
      config.value = value
      config.save!
      puts "   💾 Updated #{name} → #{value}"
    end

    def clear_cache
      GlobalConfig.clear_cache
      puts '   🗑️  Cleared configuration cache'
    end
  end
end
# rubocop:enable Metrics/BlockLength
