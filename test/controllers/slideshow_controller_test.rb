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

  test "the page sets no cookie" do
    get root_path
    assert_response :success
    assert_nil response.headers["set-cookie"], "a public slideshow has no session to keep"
    assert_select "meta[name=csrf-token]", 0
  end

  test "a polite live region names each photo change" do
    get root_path
    # One region, outside the slides, read whole on every change. It starts
    # empty so nothing is announced on page load.
    assert_select "[data-slideshow] > [data-slideshow-status][aria-live=polite][aria-atomic=true].visually-hidden", 1 do |region|
      assert_equal "", region.first.text.strip
    end
    # The stage itself is not a live region, or a change would be read twice.
    assert_select "[data-slideshow-stage][aria-live]", 0
  end

  test "wide photos offer smaller copies so phones download less" do
    get root_path

    Photo.all.each do |photo|
      assert_select "figure#photo-#{photo.number}" do
        if photo.variants.empty?
          assert_select "img[srcset]", 0
        else
          # Photo and backdrop carry the same candidates and sizes, so the
          # browser picks one file for both.
          assert_select "img.slide__photo[srcset][sizes='100vw'], img.slide__backdrop[srcset][sizes='100vw']", 2 do |imgs|
            imgs.each do |img|
              widths = img["srcset"].split(",").map { |c| c.strip.split(" ").last }
              assert_equal photo.variants.map { |v| "#{v.width}w" } + [ "#{photo.width}w" ], widths
            end
          end
        end
      end
    end

    # The 2400px photos are the ones that matter most.
    assert_select "figure#photo-9 img.slide__photo[srcset*='greig9-640w'][srcset*='greig9-1200w']"
    assert_select "figure#photo-10 img.slide__photo[srcset*='greig10-640w'][srcset*='greig10-1200w']"
  end
end
