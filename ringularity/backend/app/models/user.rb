# Represents a user in the Ringularity ecosystem.
#
# This model handles authentication via +has_secure_password+ and
# serves as the central point for all health-related data logs.
#
# @attr [String] email Unique email address used for login.
# @attr [String] password_digest Encrypted password string.
class User < ApplicationRecord
  has_secure_password

  # @!group Health Data Associations

  # @return [ActiveRecord::Relation<HeartRateLog>]
  has_many :heart_rate_logs

  # @return [ActiveRecord::Relation<StressLog>]
  has_many :stress_logs

  # @return [ActiveRecord::Relation<HrvLog>]
  has_many :hrv_logs

  # @return [ActiveRecord::Relation<SleepLog>]
  has_many :sleep_logs

  # @return [ActiveRecord::Relation<StepsLog>]
  has_many :steps_logs

  # @return [ActiveRecord::Relation<ActivityLog>]
  has_many :activity_logs

  # @!group
end
