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
| The photos (compressed, metadata stripped) | `app/assets/images/photos/greig1..10.jpg` |
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
- **No JavaScript, or a browser too old for import maps:** the same page reads
  as a plain stacked gallery.

To add or swap a photo: put the JPEG in `app/assets/images/photos/`, keep it
under 512 KB and no wider than 2400 px, and add its row (with real alt text and
its pixel size) to `Photo::ALL`. `PhotoTest` checks the sizes against the files.

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
`heroku config:get SECRET_KEY_BASE -a dads-app`). CI runs on every pull request
and on pushes to `accepted`, `release` and `main`.
