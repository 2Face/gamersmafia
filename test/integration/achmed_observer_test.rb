require 'test_helper'

class AchmedObserverTest < ActionController::IntegrationTest
  def setup
    ActionController::Base.perform_caching = true
    host! App.domain
  end

  test "should create slog entry if ammount > 5000" do
    assert_count_increases(SlogEntry) do
      Bank.transfer(:bank, User.find(1), AchmedObserver::CASH_MOVEMENT_SUSPICIOUSNESS_THRESHOLD, 'ta')
    end
  end

  def teardown
    ActionController::Base.perform_caching             = false
  end
end
