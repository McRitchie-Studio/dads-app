# dads-app

Greig McRitchie's photo slideshow — greigmcritchie.com

A single full-screen slideshow of the ten photos from the 2015 Christmas gift
([amcritchie/grieg_mcritchie](https://github.com/amcritchie/grieg_mcritchie)).
It is a Rails 8.1 app with **no database** and no studio-engine, so it runs on
one Heroku Eco dyno for about $5 a month.

## How it works

| Piece | Where |
|-------|-------|
| The photo list (number, size, alt text) | `app/models/photo.rb` — a plain `Data` class; there is no database |
| The photos (compressed, metadata stripped) | `app/assets/images/photos/greig1..10.jpg`, plus smaller `greigN-640w.jpg` / `greigN-1200w.jpg` copies of the wide ones |
| The page | `app/views/slideshow/index.html.erb` at `/` |
| The behavior | `app/javascript/slideshow.js` (plain ES module through importmap) |
| The look | `app/assets/stylesheets/application.css` (plain CSS) |
| Health check | `/up` |

- **Keyboard:** Left/Right (or Page Up/Down) step, Home/End jump, Space or K
  plays and pauses, F toggles full screen.
- **Touch:** swipe left or right; a tap brings the controls back.
- **Full screen:** a button where the browser supports it. iPhone Safari cannot
  put a page full screen, so the button hides there; the page already fills the
  screen edge to edge, and "Add to Home Screen" opens it without browser chrome.
- **Reduced motion:** no autoplay, and photos cut instead of fading or drifting.
- **Screen readers:** a visually hidden live region says "Photo 2 of 10: ..."
  with the alt text on each change while the viewer is driving; it goes quiet
  during autoplay.
- **Idle chrome:** the controls fade after three seconds without input, also
  after a mouse click or a tap leaves focus on a button. Only keyboard focus
  (`:focus-visible`) keeps them up.
- **Phones:** wide photos list their smaller copies in `srcset` (`sizes="100vw"`),
  so a phone downloads a 640 or 1200 px copy instead of the 2400 px original.
- **No cookies:** the session store is disabled and there is no CSRF meta tag;
  the page is public and has no forms.
- **No JavaScript, or a browser too old for import maps:** the same page reads
  as a plain stacked gallery.

To add or swap a photo: put the JPEG in `app/assets/images/photos/`, keep it
under 512 KB and no wider than 2400 px, and add its row (with real alt text and
its pixel size) to `Photo::ALL`. If it is wider than 640 px, also add a copy at
each narrower `Photo::VARIANT_WIDTHS` entry:

```bash
magick greigN.jpg -resize 640x -strip -quality 80 -interlace JPEG greigN-640w.jpg
```

`PhotoTest` checks every size, and every copy, against the files.

## Develop

```bash
bundle install
bin/rails server -p 3701     # dads-app uses ports 3700-3799
bin/rails test               # unit + component
bin/rails test:system        # the slideshow in headless Chrome
bin/ci                       # everything CI runs
```

## Deploy

Heroku app `dads-app`, `heroku/ruby` buildpack, no add-ons, one `web` process
(`Procfile`, no release phase since there is nothing to migrate). There is no
`config/credentials.yml.enc`; production reads `SECRET_KEY_BASE` from the
environment, which the Ruby buildpack sets on the first deploy (check with
`heroku config:get SECRET_KEY_BASE -a dads-app`). Production forces HTTPS: the
Heroku router reports the visitor's scheme in `X-Forwarded-Proto`, so
`assume_ssl` stays off and plain `http://` gets a 301, except `/up`, which
answers on either scheme (`ProductionSslTest` boots production to prove it).
CI runs on every pull request
and on pushes to `accepted`, `release` and `main`.
