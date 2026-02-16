class User < ApplicationRecord
  has_secure_password

  has_many :heart_rate_logs
  has_many :stress_logs
  has_many :hrv_logs
  has_many :sleep_logs
  has_many :steps_logs
end
