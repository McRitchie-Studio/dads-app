require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # The controls are icon buttons named by aria-label.
  Capybara.enable_aria_label = true
end
