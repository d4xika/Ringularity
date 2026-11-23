ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class AccountDeletionTest < ActionDispatch::IntegrationTest
  ASSOCIATIONS = %i[heart_rate_logs hrv_logs stress_logs sleep_logs steps_logs activity_logs].freeze

  setup do
    @user = User.create!(email: "delete@example.com", password: "password", auth_key: "delete-key")
    @other = User.create!(email: "keep@example.com", password: "password", auth_key: "keep-key")
    samples = {
      heart_rate_logs: { bpm: 72 },
      hrv_logs: { hrv_val: 40 },
      stress_logs: { stress_level: 20 },
      sleep_logs: { sleep_stage: 2, duration_minutes: 60 },
      steps_logs: { steps: 1000 },
      activity_logs: { activity_type: "walk", custom_title: "Synthetic activity", duration: 300,
                      hr_trace: [72, 74], route: [{ latitude: 0.0, longitude: 0.0 }] }
    }
    [@user, @other].each do |user|
      samples.each { |name, attributes| user.public_send(name).create!(attributes.merge(recorded_at: Time.current)) }
    end
    @other_data = ASSOCIATIONS.to_h { |name| [name, @other.public_send(name).order(:id).map(&:attributes)] }
    @headers = { "X-User-Id" => @user.id.to_s, "X-Auth-Key" => @user.auth_key }
  end

  test "deletion removes every associated collection and preserves other accounts" do
    delete "/api/users/account", headers: @headers, params: { current_password: "password" }, as: :json
    assert_response :no_content
    assert_not User.exists?(@user.id)
    ASSOCIATIONS.each do |name|
      model = User.reflect_on_association(name).klass
      assert_empty model.where(user_id: @user.id)
      assert_equal 1, model.where(user_id: @other.id).count
    end
    assert User.exists?(@other.id)
    assert_equal @other.attributes, @other.reload.attributes
    assert_equal @other_data, ASSOCIATIONS.to_h { |name| [name, @other.public_send(name).order(:id).map(&:attributes)] }
    post "/api/users/authorize", params: { user_id: @user.id, auth_key: @user.auth_key }, as: :json
    assert_response :unauthorized
    post "/api/users/login", params: { email: @user.email, password: "password" }, as: :json
    assert_response :unauthorized
    get "/api/users/export_data", headers: @headers
    assert_response :unauthorized
    delete "/api/users/account", headers: @headers, params: { current_password: "password" }, as: :json
    assert_response :no_content
  end

  test "wrong password missing token and another account token cannot delete data" do
    [
      [@headers, "wrong"],
      [{ "X-User-Id" => @user.id.to_s }, "password"],
      [@headers.merge("X-Auth-Key" => @other.auth_key), "password"]
    ].each do |headers, password|
      delete "/api/users/account", headers: headers, params: { current_password: password }, as: :json
      assert_response :unauthorized
      assert User.exists?(@user.id)
      ASSOCIATIONS.each { |name| assert_equal 1, @user.public_send(name).count }
    end
  end

  test "missing password does not delete the account" do
    delete "/api/users/account", headers: @headers, as: :json
    assert_response :bad_request
    assert User.exists?(@user.id)
  end

  test "database cascade also removes data when model callbacks are bypassed" do
    @user.delete
    ASSOCIATIONS.each do |name|
      assert_empty User.reflect_on_association(name).klass.where(user_id: @user.id)
    end
  end

  test "failed deletion rolls back the account and associated deletions" do
    deleted_id = @user.id
    callback = ->(user) { throw :abort if user.id == deleted_id }
    User.set_callback(:destroy, :before, callback)
    assert_raises(ActiveRecord::RecordNotDestroyed) { @user.destroy! }
    assert User.exists?(@user.id)
    ASSOCIATIONS.each { |name| assert_equal 1, @user.public_send(name).count }
  ensure
    User.skip_callback(:destroy, :before, callback)
  end
end
