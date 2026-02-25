# Represents a Heart Rate Variability (HRV) measurement.
# HRV is a key indicator of autonomic nervous system balance, recovery, and stress.
#
# @attr [Integer] hrv_val The HRV value (typically measured as RMSSD in milliseconds).
# @attr [DateTime] recorded_at The exact timestamp of the measurement.
# @attr [Integer] user_id Foreign key to the associated {User}.
class HrvLog < ApplicationRecord
  # @!group Associations

  # @return [User] The user this HRV log belongs to.
  belongs_to :user

  # @!endgroup
end