require "application_system_test_case"

class SlideshowTest < ApplicationSystemTestCase
  test "the script takes over: js class, first photo, autoplay on" do
    visit_slideshow

    assert_selector "html.js"
    assert_counter "1 / 10"
    assert_active_photo 1
    assert_selector "[data-action=toggle][aria-pressed=true][aria-label='Pause slideshow']"
    # Inactive slides are hidden from assistive tech and focus.
    assert_equal 9, page.evaluate_script("document.querySelectorAll('[data-slide][inert][aria-hidden=true]').length")
  end

  test "arrow keys step through the photos and wrap at both ends" do
    visit_slideshow

    press :right
    assert_active_photo 2
    assert_counter "2 / 10"

    press :left
    press :left
    assert_active_photo 10
    assert_counter "10 / 10"

    press :right
    assert_active_photo 1

    press :end
    assert_active_photo 10
    press :home
    assert_active_photo 1
  end

  test "space pauses and resumes the slideshow" do
    visit_slideshow

    press :space
    assert_selector "[data-slideshow][data-playing=false]"
    assert_selector "[data-action=toggle][aria-pressed=false][aria-label='Play slideshow']"
    # Paused, the photo changes are announced.
    assert_selector "[data-slideshow-stage][aria-live=polite]"

    press :space
    assert_selector "[data-slideshow][data-playing=true]"
    assert_selector "[data-slideshow-stage][aria-live=off]"
  end

  test "the buttons step, pause and show full screen" do
    visit_slideshow

    click_on "Next photo"
    assert_active_photo 2
    click_on "Previous photo"
    click_on "Previous photo"
    assert_active_photo 10

    click_on "Pause slideshow"
    assert_selector "[data-slideshow][data-playing=false]"

    # Headless Chrome supports the Fullscreen API, so the button is offered.
    assert_selector "button[data-action=fullscreen]:not([hidden])[aria-label='Enter full screen']"
  end

  test "autoplay advances on its own" do
    visit_slideshow
    page.execute_script("window.slideshow.interval = 150; window.slideshow.play()")

    assert_active_photo 2
  end

  test "a swipe left goes forward and a swipe right goes back" do
    visit_slideshow

    swipe from: 900, to: 400
    assert_active_photo 2

    swipe from: 400, to: 900
    swipe from: 400, to: 900
    assert_active_photo 10

    # A mostly vertical drag is not a swipe.
    swipe from: 600, to: 560, dy: 300
    assert_active_photo 10
  end

  test "reduced motion: no autoplay, and no fade" do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia",
      features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    visit_slideshow

    assert_selector "[data-slideshow][data-playing=false]"
    assert_equal "0s", page.evaluate_script(
      "getComputedStyle(document.querySelector('[data-slide]')).transitionDuration.split(',')[0].trim()")

    press :right
    assert_active_photo 2
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  private

  def visit_slideshow
    visit root_path
    assert_selector "[data-slideshow][data-ready=true]"
  end

  def press(key)
    find("body").send_keys(key)
  end

  def assert_active_photo(number)
    assert_selector "figure.is-active[data-slide]", count: 1
    assert_selector "figure#photo-#{number}.is-active[aria-hidden=false]"
  end

  def assert_counter(text)
    assert_selector "[data-slideshow-counter]", exact_text: text
  end

  # Drives the stage's pointer handlers the way a finger does: down, then up
  # somewhere else.
  def swipe(from:, to:, dy: 0)
    page.execute_script(<<~JS, from, to, dy)
      const [from, to, dy] = arguments
      const stage = document.querySelector("[data-slideshow-stage]")
      const opts = { bubbles: true, isPrimary: true, pointerType: "touch", pointerId: 7 }
      stage.dispatchEvent(new PointerEvent("pointerdown", { ...opts, clientX: from, clientY: 400 }))
      stage.dispatchEvent(new PointerEvent("pointerup", { ...opts, clientX: to, clientY: 400 + dy }))
    JS
  end
end
