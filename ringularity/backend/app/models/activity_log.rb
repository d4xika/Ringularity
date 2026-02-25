# Represents a physical activity tracked by the user (e.g., Running, Cycling).
#
# This model stores both summary data (distance, duration) and complex
# time-series data like heart rate traces and GPS routes.
#
# @attr [String] activity_type The category of activity (e.g., 'Walking', 'Strength').
# @attr [String] custom_title A user-defined name for the activity session.
# @attr [DateTime] recorded_at The start time of the activity.
# @attr [Integer] duration Duration of the activity in seconds.
# @attr [Float] distance Distance covered in kilometers.
# @attr [Integer] avg_heart_rate Average heart rate during the session.
# @attr [Integer] steps Number of steps taken during the activity.
# @attr [JSON/Array] hr_trace High-resolution heart rate data points.
# @attr [JSON/Array] route GPS coordinates or path data.
# @attr [Integer] user_id Foreign key connecting the log to a {User}.
class ActivityLog < ApplicationRecord
  # @!group Associations

  # @return [User] The owner of this activity log.
  belongs_to :user

  # @!endgroup
end
