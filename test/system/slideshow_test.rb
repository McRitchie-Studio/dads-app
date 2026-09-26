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
    assert_selector "[data-slideshow-status][aria-live=polite]", visible: :all

    press :space
    assert_selector "[data-slideshow][data-playing=true]"
    assert_selector "[data-slideshow-status][aria-live=off]", visible: :all
  end

  test "each photo change is announced by name and position" do
    visit_slideshow
    press :space
    assert_selector "[data-slideshow][data-playing=false]"
    # Nothing is said on load.
    assert_equal "", status_text

    press :right
    assert_active_photo 2
    assert_equal "Photo 2 of 10: #{Photo.all[1].alt}", status_text

    click_on "Previous photo"
    click_on "Previous photo"
    assert_active_photo 10
    assert_equal "Photo 10 of 10: #{Photo.all[9].alt}", status_text
  end

  test "the controls fade after a mouse click even though the button keeps focus" do
    visit_slideshow

    click_on "Next photo"
    assert_active_photo 2
    assert page.evaluate_script("document.activeElement.dataset.action === 'next'"), "the click focused Next"

    page.execute_script("window.slideshow.sleep()")
    assert_selector "[data-slideshow].is-idle"
    assert_controls_faded
  end

  test "the controls fade after a finger tap on a button" do
    visit_slideshow

    button = find("[data-action=next]").native
    finger = Selenium::WebDriver::Interactions.pointer(:touch, name: "finger")
    page.driver.browser.action(devices: [ finger ])
      .move_to(button).pointer_down(:left).pointer_up(:left).perform
    assert_active_photo 2

    page.execute_script("window.slideshow.sleep()")
    assert_selector "[data-slideshow].is-idle"
    assert_controls_faded
  end

  # Chrome fires a mousemove at a resting cursor when the element under it
  # changes, and the idle bar dropping its pointer events is such a change.
  # Waking on that would bring the controls straight back (CI caught it).
  test "a mouse that has not moved does not wake the controls" do
    visit_slideshow
    move_mouse_to 300, 300
    page.execute_script("window.slideshow.sleep()")
    assert_selector "[data-slideshow].is-idle"

    move_mouse_to 300, 300
    assert_selector "[data-slideshow].is-idle"

    move_mouse_to 340, 300
    assert_no_selector "[data-slideshow].is-idle"
  end

  test "keyboard focus on a control keeps the controls up" do
    visit_slideshow

    press :tab
    assert page.evaluate_script("document.activeElement.matches('.control:focus-visible')"), "Tab focused a control"

    page.execute_script("window.slideshow.sleep()")
    assert_no_selector "[data-slideshow].is-idle"
  end

  test "a phone downloads the smaller copy of a wide photo" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: 390, height: 844, deviceScaleFactor: 3, mobile: true)
    visit_slideshow

    press :end
    assert_active_photo 10
    src = nil
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until (src = page.evaluate_script("document.querySelector('#photo-10 .slide__photo').currentSrc")).present?
    end
    # 390 CSS px at 3x wants about 1170 device px: the 1200w copy, not the 2400px original.
    assert_match %r{/photos/greig10-1200w-[^/]*\.jpg\z}, src
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
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

  test "idle controls are invisible and let a tap through to the stage" do
    visit_slideshow
    page.execute_script("window.slideshow.sleep()")
    assert_selector "[data-slideshow].is-idle"

    # A finger landing where Next sits must wake the chrome, not press Next.
    hit = page.evaluate_script(<<~JS)
      (() => { const r = document.querySelector("[data-action=next]").getBoundingClientRect()
        return document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2).closest("[data-slideshow-controls]") })()
    JS
    assert_nil hit
  end

  test "autoplay advances on its own" do
    visit_slideshow
    # Shorten the clock, and freeze the show after its first automatic step so
    # the assertion cannot race a fast interval past photo 2.
    page.execute_script(<<~JS)
      const show = window.slideshow
      const step = show.next.bind(show)
      show.next = () => { step(); show.pause(); document.body.dataset.advanced = String(show.index + 1) }
      show.interval = 150
      show.play()
    JS

    assert_selector "body[data-advanced='2']"
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

  # The class alone is not the fade: CSS must actually take the bar to zero
  # opacity and stop it catching taps.
  def assert_controls_faded
    faded = -> {
      page.evaluate_script(<<~JS)
        (() => { const s = getComputedStyle(document.querySelector("[data-slideshow-controls]"))
          return s.opacity === "0" && s.pointerEvents === "none" })()
      JS
    }
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until faded.call }
  rescue Timeout::Error
    flunk "the controls stayed visible or tappable"
  end

  def move_mouse_to(x, y)
    page.execute_script(<<~JS, x, y)
      const [x, y] = arguments
      document.querySelector("[data-slideshow-stage]").dispatchEvent(
        new MouseEvent("mousemove", { bubbles: true, clientX: x, clientY: y, screenX: x, screenY: y }))
    JS
  end

  def status_text
    page.evaluate_script("document.querySelector('[data-slideshow-status]').textContent").strip
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
