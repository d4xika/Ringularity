# Records sleep stages and duration data.
#
# @attr [String] sleep_stage The type of sleep (e.g., 'REM', 'Deep', 'Light').
# @attr [Integer] duration_minutes How long the user remained in this stage.
# @attr [DateTime] recorded_at The start time of this specific sleep stage.
# @attr [Integer] user_id Foreign key to the associated {User}.
class SleepLog < ApplicationRecord
  # @!group Associations
  # @return [User] The owner of this sleep log.
  belongs_to :user
  # @!endgroup
end