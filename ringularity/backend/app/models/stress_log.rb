# Represents a calculated stress level measurement.
#
# @attr [Integer] stress_level The stress score (typically on a scale of 1-100).
# @attr [DateTime] recorded_at The timestamp of the measurement.
# @attr [Integer] user_id Foreign key to the associated {User}.
class StressLog < ApplicationRecord
  # @!group Associations
  # @return [User] The owner of this stress log.
  belongs_to :user
  # @!endgroup
end