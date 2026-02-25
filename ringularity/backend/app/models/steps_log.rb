# Stores step count data synced from the wearable device.
#
# @attr [Integer] steps The number of steps recorded in this interval.
# @attr [DateTime] recorded_at The timestamp when the steps were logged.
# @attr [Integer] user_id Foreign key to the associated {User}.
class StepsLog < ApplicationRecord
  # @!group Associations
  # @return [User] The owner of this steps log.
  belongs_to :user
  # @!endgroup
end