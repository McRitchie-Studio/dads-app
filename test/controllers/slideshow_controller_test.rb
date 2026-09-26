require "test_helper"

# Component tier: the slideshow page as rendered HTML.
class SlideshowControllerTest < ActionDispatch::IntegrationTest
  test "/up answers 200 with no database" do
    get rails_health_check_path
    assert_response :success
  end

  test "the home page is the slideshow, titled for Greig" do
    get root_path
    assert_response :success
    assert_select "title", "Greig McRitchie"
    assert_select "h1", "Greig McRitchie"
    assert_select "html[lang=en].no-js"
    assert_select "meta[name=viewport][content*='viewport-fit=cover']"
  end

  test "renders all ten photos, each with its alt text, first one active" do
    get root_path

    assert_select "[data-slideshow][aria-roledescription=carousel]" do
      assert_select "figure[data-slide][role=group][aria-roledescription=slide]", 10
      assert_select "figure[data-slide].is-active", 1
      assert_select "figure[data-slide]:first-of-type.is-active"

      Photo.all.each_with_index do |photo, index|
        assert_select "figure#photo-#{photo.number}[aria-label=?]", "#{index + 1} of 10" do
          assert_select "img.slide__photo[alt=?][width=?][height=?]",
            photo.alt, photo.width.to_s, photo.height.to_s, 1
          # The blurred backdrop is decoration and must stay silent.
          assert_select "img.slide__backdrop[alt=''][aria-hidden=true]", 1
        end
      end
    end
  end

  test "only the first photo loads eagerly" do
    get root_path
    assert_select "img.slide__photo[loading=eager][fetchpriority=high]", 1
    assert_select "img.slide__photo[loading=lazy]", 9
  end

  test "renders labelled controls" do
    get root_path

    assert_select "nav[aria-label='Slideshow controls']" do
      assert_select "button[type=button][data-action=prev][aria-label='Previous photo']"
      assert_select "button[type=button][data-action=next][aria-label='Next photo']"
      assert_select "button[type=button][data-action=toggle][aria-pressed=false][aria-label='Play slideshow']"
      # Hidden until the script confirms the browser can go full screen.
      assert_select "button[type=button][data-action=fullscreen][hidden]"
      assert_select "[data-slideshow-counter]", "1 / 10"
    end
  end
end
