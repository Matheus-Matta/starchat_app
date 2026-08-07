module Featurable
  extend ActiveSupport::Concern

  QUERY_MODE = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze

  FEATURE_LIST = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze
  FEATURE_FLAG_LIMIT = 63
  OVERFLOW_FEATURES_KEY = 'overflow_feature_flags'

  DATABASE_FEATURE_LIST = FEATURE_LIST.first(FEATURE_FLAG_LIMIT).freeze
  OVERFLOW_FEATURE_NAMES = FEATURE_LIST.drop(FEATURE_FLAG_LIMIT).pluck('name').freeze

  FEATURES = DATABASE_FEATURE_LIST.each_with_object({}) do |feature, result|
    result[result.keys.size + 1] = "feature_#{feature['name']}".to_sym
  end

  included do
    include FlagShihTzu
    has_flags FEATURES.merge(column: 'feature_flags').merge(QUERY_MODE)

    alias_method :database_selected_feature_flags, :selected_feature_flags
    alias_method :database_selected_feature_flags=, :selected_feature_flags=

    define_method(:selected_feature_flags) do
      database_selected_feature_flags + selected_overflow_feature_flags
    end

    define_method(:selected_feature_flags=) do |chosen_flags|
      selected_flags = Array(chosen_flags).select(&:present?).map(&:to_s)
      database_selected_feature_flags = selected_flags.reject { |flag| overflow_feature_flag?(flag) }
      overflow_selected_feature_flags = selected_flags.select { |flag| overflow_feature_flag?(flag) }

      self.database_selected_feature_flags = database_selected_feature_flags
      select_overflow_feature_flags(overflow_selected_feature_flags)
    end

    OVERFLOW_FEATURE_NAMES.each do |name|
      define_method("feature_#{name}") do
        overflow_feature_enabled?(name)
      end

      define_method("feature_#{name}?") do
        overflow_feature_enabled?(name)
      end

      define_method("feature_#{name}=") do |value|
        set_overflow_feature(name, ActiveModel::Type::Boolean.new.cast(value))
      end

      scope "feature_#{name}", lambda {
        where("internal_attributes -> ? @> ?::jsonb", OVERFLOW_FEATURES_KEY, [name].to_json)
      }
    end

    before_create :enable_default_features
  end

  def enable_features(*names)
    names.each do |name|
      if overflow_feature_name?(name)
        set_overflow_feature(name, true)
      else
        send("feature_#{name}=", true)
      end
    end
  end

  def enable_features!(*names)
    enable_features(*names)
    save
  end

  def disable_features(*names)
    names.each do |name|
      if overflow_feature_name?(name)
        set_overflow_feature(name, false)
      else
        send("feature_#{name}=", false)
      end
    end
  end

  def disable_features!(*names)
    disable_features(*names)
    save
  end

  def feature_enabled?(name)
    return overflow_feature_enabled?(name) if overflow_feature_name?(name)

    send("feature_#{name}?")
  end

  def all_features
    FEATURE_LIST.pluck('name').index_with do |feature_name|
      feature_enabled?(feature_name)
    end
  end

  def enabled_features
    all_features.select { |_feature, enabled| enabled == true }
  end

  def disabled_features
    all_features.select { |_feature, enabled| enabled == false }
  end

  private

  def selected_overflow_feature_flags
    overflow_feature_names.map { |name| :"feature_#{name}" }
  end

  def select_overflow_feature_flags(flags)
    selected_names = flags.map { |flag| normalize_overflow_feature_name(flag) }.compact
    update_overflow_feature_names(selected_names)
  end

  def set_overflow_feature(name, enabled)
    names = overflow_feature_names
    normalized_name = name.to_s

    names = enabled ? (names | [normalized_name]) : (names - [normalized_name])
    update_overflow_feature_names(names)
  end

  def overflow_feature_enabled?(name)
    overflow_feature_names.include?(name.to_s)
  end

  def overflow_feature_flag?(flag)
    normalize_overflow_feature_name(flag).present?
  end

  def overflow_feature_name?(name)
    OVERFLOW_FEATURE_NAMES.include?(name.to_s)
  end

  def normalize_overflow_feature_name(flag)
    name = flag.to_s.delete_prefix('feature_')
    name if overflow_feature_name?(name)
  end

  def overflow_feature_names
    Array(internal_attributes&.[](OVERFLOW_FEATURES_KEY)).map(&:to_s)
  end

  def update_overflow_feature_names(names)
    attrs = (internal_attributes || {}).deep_dup
    attrs[OVERFLOW_FEATURES_KEY] = names.select { |name| overflow_feature_name?(name) }.uniq
    self.internal_attributes = attrs
  end

  def enable_default_features
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return true if config.blank?

    features_to_enabled = config.value.select { |f| f[:enabled] }.pluck(:name)
    enable_features(*features_to_enabled)
  end
end
