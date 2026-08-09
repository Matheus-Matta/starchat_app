class BackfillOverflowFeatureFlagsToExtColumn < ActiveRecord::Migration[7.1]
  # Before this port, this fork carried 66 feature flags. FlagShihTzu only fits 63 per
  # column, so the last three — advanced_assignment, channel_ycloud and
  # audio_transcription — were kept in internal_attributes->overflow_feature_flags
  # instead of a bit.
  #
  # Upstream's two-column Featurable replaces that overflow entirely: those three now
  # live on feature_flags_ext_1. Nothing reads the JSONB key anymore, so without this
  # backfill every account that had one of them enabled would silently lose it.
  #
  # Bits match config/features.yml: advanced_assignment 1, channel_ycloud 2,
  # audio_transcription 4. Idempotent — OR-ing an already-set bit is a no-op.
  OVERFLOW_BITS = {
    'advanced_assignment' => 1,
    'channel_ycloud' => 2,
    'audio_transcription' => 4
  }.freeze

  def up
    OVERFLOW_BITS.each do |feature, bit|
      execute(<<~SQL.squish)
        UPDATE accounts
        SET feature_flags_ext_1 = COALESCE(feature_flags_ext_1, 0) | #{bit}
        WHERE internal_attributes -> 'overflow_feature_flags' @> '["#{feature}"]'::jsonb
      SQL
    end
  end

  def down
    # The JSONB key is left untouched by #up, so rolling back only needs to clear the bits.
    OVERFLOW_BITS.each_value do |bit|
      execute(<<~SQL.squish)
        UPDATE accounts
        SET feature_flags_ext_1 = COALESCE(feature_flags_ext_1, 0) & ~#{bit}
      SQL
    end
  end
end
