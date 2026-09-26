// The full-screen slideshow. Plain DOM, no framework: one root element marked
// [data-slideshow] holds the slides ([data-slide]) and the controls.
//
//   Keyboard  ArrowLeft/ArrowRight (also PageUp/PageDown), Home/End,
//             Space or K to play/pause, F to toggle full screen
//   Touch     swipe left/right; a tap brings the controls back
//   Motion    autoplays unless the viewer prefers reduced motion, and then
//             cuts between photos instead of fading (see the CSS)

const IDLE_AFTER_MS = 3000
const HINT_FOR_MS = 4000
const SWIPE_MIN_PX = 40

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

export class Slideshow {
  constructor(root) {
    this.root = root
    this.stage = root.querySelector("[data-slideshow-stage]")
    this.slides = Array.from(root.querySelectorAll("[data-slide]"))
    this.counter = root.querySelector("[data-slideshow-counter]")
    this.hint = root.querySelector("[data-slideshow-hint]")
    this.toggleButton = root.querySelector('[data-action="toggle"]')
    this.fullscreenButton = root.querySelector('[data-action="fullscreen"]')
    this.interval = Number(root.dataset.interval) || 6000
    this.index = Math.max(0, this.slides.findIndex((slide) => slide.classList.contains("is-active")))
    this.timer = null
    this.idleTimer = null
  }

  start() {
    this.show(this.index, { restart: true })
    this.bindControls()
    this.bindKeyboard()
    this.bindSwipe()
    this.bindIdle()
    this.bindFullscreen()
    this.bindVisibility()
    this.showHint()

    if (!reducedMotion.matches) this.play()
    else this.pause()

    // A viewer who turns reduced motion on mid-show gets a still show.
    reducedMotion.addEventListener?.("change", (event) => {
      if (event.matches) this.pause()
    })

    this.root.dataset.ready = "true"
  }

  // ---- navigation -------------------------------------------------------

  get count() {
    return this.slides.length
  }

  show(index, { restart = false } = {}) {
    const next = ((index % this.count) + this.count) % this.count

    this.slides.forEach((slide, i) => {
      const active = i === next
      if (active && restart) {
        // Re-add the class after a reflow so the first photo's drift runs too.
        slide.classList.remove("is-active")
        void slide.offsetWidth
      }
      slide.classList.toggle("is-active", active)
      slide.setAttribute("aria-hidden", active ? "false" : "true")
      slide.inert = !active
    })

    this.index = next
    this.counter.textContent = `${next + 1} / ${this.count}`
    this.warm(next + 1)
  }

  next() {
    this.show(this.index + 1)
  }

  prev() {
    this.show(this.index - 1)
  }

  // Lazy images that are hidden may not load until shown; ask for the next
  // one early so the fade never lands on a blank frame.
  warm(index) {
    const slide = this.slides[index % this.count]
    slide?.querySelectorAll("img[loading=lazy]").forEach((img) => { img.loading = "eager" })
  }

  // A manual step restarts the autoplay clock so the new photo gets its full time.
  step(direction) {
    direction > 0 ? this.next() : this.prev()
    if (this.playing) this.play()
  }

  // ---- autoplay ---------------------------------------------------------

  get playing() {
    return this.timer !== null
  }

  play() {
    clearInterval(this.timer)
    this.timer = setInterval(() => this.next(), this.interval)
    this.syncPlaying()
  }

  pause() {
    clearInterval(this.timer)
    this.timer = null
    this.syncPlaying()
  }

  togglePlay() {
    this.playing ? this.pause() : this.play()
  }

  syncPlaying() {
    const playing = this.playing
    this.root.dataset.playing = String(playing)
    this.toggleButton.setAttribute("aria-pressed", String(playing))
    this.toggleButton.setAttribute("aria-label", playing ? "Pause slideshow" : "Play slideshow")
    // Announce each photo only when the viewer is driving; a live region
    // that talks every six seconds is noise.
    this.stage.setAttribute("aria-live", playing ? "off" : "polite")
  }

  // ---- input ------------------------------------------------------------

  bindControls() {
    this.root.addEventListener("click", (event) => {
      const button = event.target.closest("[data-action]")
      if (!button) return
      switch (button.dataset.action) {
        case "prev": this.step(-1); break
        case "next": this.step(1); break
        case "toggle": this.togglePlay(); break
        case "fullscreen": this.toggleFullscreen(); break
      }
    })
  }

  bindKeyboard() {
    document.addEventListener("keydown", (event) => {
      if (event.altKey || event.ctrlKey || event.metaKey) return
      // Let Space and Enter press a focused button as usual.
      const onButton = event.target.closest?.("button")

      switch (event.key) {
        case "ArrowRight":
        case "PageDown":
          this.step(1); break
        case "ArrowLeft":
        case "PageUp":
          this.step(-1); break
        case "Home":
          this.show(0); if (this.playing) this.play(); break
        case "End":
          this.show(this.count - 1); if (this.playing) this.play(); break
        case " ":
        case "k":
        case "K":
          if (onButton && event.key === " ") return
          this.togglePlay(); break
        case "f":
        case "F":
          if (this.fullscreenButton.hidden) return
          this.toggleFullscreen(); break
        default:
          return
      }
      event.preventDefault()
      this.wake()
    })
  }

  bindSwipe() {
    let start = null

    this.stage.addEventListener("pointerdown", (event) => {
      if (!event.isPrimary) return
      start = { x: event.clientX, y: event.clientY }
    })

    this.stage.addEventListener("pointercancel", () => { start = null })

    this.stage.addEventListener("pointerup", (event) => {
      if (!start || !event.isPrimary) return
      const dx = event.clientX - start.x
      const dy = event.clientY - start.y
      start = null

      if (Math.abs(dx) >= SWIPE_MIN_PX && Math.abs(dx) > Math.abs(dy)) {
        // Swipe left moves forward, like turning a page.
        this.step(dx < 0 ? 1 : -1)
        this.wake()
      } else {
        // A tap brings the controls back.
        this.wake()
      }
    })
  }

  // ---- idle chrome ------------------------------------------------------

  bindIdle() {
    const wake = () => this.wake()
    this.root.addEventListener("mousemove", wake, { passive: true })
    this.root.addEventListener("focusin", wake)
    this.wake()
  }

  wake() {
    this.root.classList.remove("is-idle")
    clearTimeout(this.idleTimer)
    this.idleTimer = setTimeout(() => this.sleep(), IDLE_AFTER_MS)
  }

  sleep() {
    clearTimeout(this.idleTimer)
    // Never hide the controls out from under keyboard focus.
    if (this.root.querySelector("[data-slideshow-controls]").contains(document.activeElement)) return
    this.root.classList.add("is-idle")
  }

  showHint() {
    if (!this.hint) return
    const touch = window.matchMedia("(pointer: coarse)").matches
    this.hint.textContent = touch ? "Swipe to browse" : "Use the arrow keys to browse"
    setTimeout(() => this.hint.classList.add("is-gone"), HINT_FOR_MS)
  }

  // ---- full screen ------------------------------------------------------

  // iPhone Safari cannot put a page element full screen (only video), so the
  // button stays hidden there; the page already fills the screen edge to edge
  // and goes chrome-free when added to the home screen.
  get fullscreenSupported() {
    const el = document.documentElement
    return Boolean(el.requestFullscreen || el.webkitRequestFullscreen) &&
      document.fullscreenEnabled !== false
  }

  get fullscreenElement() {
    return document.fullscreenElement || document.webkitFullscreenElement || null
  }

  bindFullscreen() {
    if (!this.fullscreenSupported) return
    this.fullscreenButton.hidden = false
    const sync = () => {
      const on = this.fullscreenElement !== null
      this.fullscreenButton.setAttribute("aria-pressed", String(on))
      this.fullscreenButton.setAttribute("aria-label", on ? "Exit full screen" : "Enter full screen")
    }
    document.addEventListener("fullscreenchange", sync)
    document.addEventListener("webkitfullscreenchange", sync)
    sync()
  }

  toggleFullscreen() {
    if (this.fullscreenElement) {
      const exit = document.exitFullscreen || document.webkitExitFullscreen
      exit?.call(document)?.catch?.(() => {})
    } else {
      const el = document.documentElement
      const request = el.requestFullscreen || el.webkitRequestFullscreen
      request?.call(el, { navigationUI: "hide" })?.catch?.(() => {})
    }
  }

  // ---- housekeeping -----------------------------------------------------

  // Stop the clock while the tab is hidden so nobody returns to photo 7 of 10
  // having missed the rest; resume if it was playing.
  bindVisibility() {
    let resume = false
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        resume = this.playing
        this.pause()
      } else if (resume) {
        this.play()
      }
    })
  }
}

export function startSlideshow(root = document.querySelector("[data-slideshow]")) {
  if (!root) return null
  document.documentElement.classList.replace("no-js", "js")
  const slideshow = new Slideshow(root)
  slideshow.start()
  window.slideshow = slideshow
  return slideshow
}
