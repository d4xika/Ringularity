# Stores individual heart rate measurements (BPM) synced from the ring.
#
# @attr [Integer] bpm Beats per minute.
# @attr [DateTime] recorded_at The exact timestamp when the heart rate was measured.
# @attr [Integer] user_id Foreign key to the associated {User}.
class HeartRateLog < ApplicationRecord
  # @!group Associations

  # @return [User] The user this heart rate log belongs to.
  belongs_to :user

  # @!endgroup
end