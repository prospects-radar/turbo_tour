import { Controller } from "@hotwired/stimulus"

const DEFAULT_CLASSES = ""
const DEFAULT_KEY = "turbo_tour_session_id"
const GAP = 12
const PAD = 16
const SIZE_PRESETS = {
  small:  { width: "280px", maxHeight: "200px" },
  medium: { width: "340px", maxHeight: "320px" },
  large:  { width: "440px", maxHeight: "420px" },
  wide:   { width: "560px", maxHeight: "420px" }
}
const HOOK_NAMES = {
  "turbo-tour:start": "onStart",
  "turbo-tour:next": "onNext",
  "turbo-tour:previous": "onPrevious",
  "turbo-tour:complete": "onComplete",
  "turbo-tour:skip-tour": "onSkip"
}

const escape = (value) => window.CSS?.escape ? window.CSS.escape(value) : String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
const targetFor = (step) => document.querySelector(`[data-tour-step="${escape(step.target)}"]`)
const sessionId = () => window.crypto?.randomUUID ? window.crypto.randomUUID() : `tt-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
const normalizeHookArgs = (journeyName, handler) => typeof journeyName === "function"
  ? { journeyName: null, handler: journeyName }
  : { journeyName: journeyName ? String(journeyName) : null, handler }

const safeInvoke = (label, handler, context, scope = null) => {
  try {
    handler.call(scope, context)
  } catch (error) {
    console.error(`[TurboTour] ${label} failed`, error)
  }
}

const createRuntime = (runtime = window.TurboTour || {}) => {
  runtime._extensions ||= []
  runtime._completionHooks ||= []

  runtime.start = function start(journeyName) {
    document.dispatchEvent(new CustomEvent("turbo-tour:request-start", { detail: { journey_name: journeyName } }))
  }

  runtime.registerExtension ||= function registerExtension(extension) {
    if (!extension || typeof extension !== "object") throw new Error("TurboTour.registerExtension expects an object")

    if (extension.name) this.unregisterExtension(extension.name)
    this._extensions.push(extension)
    return extension
  }

  runtime.unregisterExtension ||= function unregisterExtension(target) {
    this._extensions = this._extensions.filter((extension) => extension !== target && extension?.name !== target)
  }

  runtime.onComplete ||= function onComplete(journeyName, handler) {
    const hook = normalizeHookArgs(journeyName, handler)
    if (typeof hook.handler !== "function") throw new Error("TurboTour.onComplete expects a callback")

    this._completionHooks.push(hook)
    return () => this.offComplete(hook.journeyName, hook.handler)
  }

  runtime.offComplete ||= function offComplete(journeyName, handler) {
    const hook = normalizeHookArgs(journeyName, handler)

    this._completionHooks = this._completionHooks.filter((entry) => {
      return !(entry.journeyName === hook.journeyName && entry.handler === hook.handler)
    })
  }

  runtime.runHooks ||= function runHooks(eventName, context) {
    const hookName = HOOK_NAMES[eventName]
    if (!hookName) return

    this._extensions.forEach((extension) => {
      if (typeof extension?.[hookName] === "function") {
        safeInvoke(`${extension.name || "extension"}.${hookName}`, extension[hookName], context, extension)
      }

      const journeyHook = extension?.journeys?.[context.journeyName]?.[hookName]
      if (typeof journeyHook === "function") {
        safeInvoke(`${extension.name || "extension"}.journeys.${context.journeyName}.${hookName}`, journeyHook, context, extension)
      }
    })

    if (hookName !== "onComplete") return

    this._completionHooks
      .filter((hook) => !hook.journeyName || hook.journeyName === context.journeyName)
      .forEach((hook) => safeInvoke(`completion hook for ${hook.journeyName || "all journeys"}`, hook.handler, context))
  }

  return runtime
}

const TurboTourRuntime = createRuntime(window.TurboTour || {})
window.TurboTour = TurboTourRuntime

export const start = (journeyName) => TurboTourRuntime.start(journeyName)
export const onComplete = (...args) => TurboTourRuntime.onComplete(...args)
export const offComplete = (...args) => TurboTourRuntime.offComplete(...args)
export const registerExtension = (extension) => TurboTourRuntime.registerExtension(extension)
export const unregisterExtension = (target) => TurboTourRuntime.unregisterExtension(target)
export { TurboTourRuntime }

export default class extends Controller {
  connect() {
    this.journeys = JSON.parse(this.element.dataset.turboTourJourneys || "{}")
    this.defaultJourney = this.element.dataset.turboTourJourney || Object.keys(this.journeys)[0]
    this.highlightClasses = (this.element.dataset.turboTourHighlightClasses || DEFAULT_CLASSES).split(/\s+/).filter(Boolean)
    this.storageKey = this.element.dataset.turboTourSessionStorageKey || DEFAULT_KEY
    this.skippableDefault = this.element.dataset.turboTourSkippableDefault !== "false"
    this.skippableByJourney = JSON.parse(this.element.dataset.turboTourSkippableMap || "{}")
    this.skippable = this.skippableDefault
    this.translations = JSON.parse(this.element.dataset.turboTourTranslations || "{}")
    this.tooltipSize = this.element.dataset.turboTourTooltipSize || null
    this.template = this.element.querySelector("template[data-turbo-tour-template]")
    this.onKeydown = this.keydown.bind(this)
    this.onPosition = this.position.bind(this)
    this.onStartRequest = this.requestStart.bind(this)
    this.onBeforeCache = this.beforeCache.bind(this)

    document.addEventListener("keydown", this.onKeydown)
    document.addEventListener("scroll", this.onPosition, true)
    document.addEventListener("turbo-tour:request-start", this.onStartRequest)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)
    window.addEventListener("resize", this.onPosition)

    if (this.element.dataset.turboTourAutoStart !== "false" && this.defaultJourney) this.start(this.defaultJourney)
  }

  disconnect() {
    this.end({ emit: false, restoreFocus: false })
    document.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("scroll", this.onPosition, true)
    document.removeEventListener("turbo-tour:request-start", this.onStartRequest)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    window.removeEventListener("resize", this.onPosition)
  }

  requestStart(event) {
    const journeyName = event.detail?.journey_name
    if (journeyName && this.journeys[journeyName]) this.start(journeyName)
  }

  beforeCache() {
    this.end({ emit: false, restoreFocus: false })
  }

  start(input = this.defaultJourney) {
    input?.preventDefault?.()

    const journeyName = this.resolveJourneyName(input)
    const steps = this.journeys[journeyName]
    if (!steps?.length) return false

    this.end({ emit: false, restoreFocus: false })
    this.activeJourney = journeyName
    this.steps = steps
    this.index = -1
    this.skippable = this.resolveSkippable(journeyName)
    this.session = sessionId()
    this.lastFocus = document.activeElement
    sessionStorage.setItem(this.storageKey, this.session)

    const started = this.show(0, 1, true)
    if (!started) this.end({ emit: false, restoreFocus: false })
    return started
  }

  resolveJourneyName(input) {
    if (typeof input === "string" && input.length > 0) return input
    if (input?.detail?.journey_name) return input.detail.journey_name
    if (input?.currentTarget?.dataset?.tourJourney) return input.currentTarget.dataset.tourJourney
    if (input?.params?.journey) return input.params.journey

    return this.defaultJourney
  }

  resolveSkippable(journeyName) {
    const override = this.skippableByJourney?.[journeyName]
    return typeof override === "boolean" ? override : this.skippableDefault
  }

  next(event) {
    event?.preventDefault()
    if (!this.activeJourney) return

    if (this.index >= this.steps.length - 1) {
      this.end({ eventName: "turbo-tour:complete", reason: "completed" })
      return
    }

    if (this.show(this.index + 1, 1)) {
      this.emit("turbo-tour:next")
    } else {
      this.end({ eventName: "turbo-tour:complete", reason: "completed" })
    }
  }

  previous(event) {
    event?.preventDefault()
    if (!this.activeJourney || this.index <= 0) return

    if (this.show(this.index - 1, -1)) this.emit("turbo-tour:previous")
  }

  skip(event) {
    event?.preventDefault()
    if (!this.skippable) return

    this.end({ eventName: "turbo-tour:skip-tour", reason: "skipped" })
  }

  show(index, direction = 1, emitStart = false) {
    let pointer = index
    let step
    let target

    while (pointer >= 0 && pointer < this.steps.length) {
      step = this.steps[pointer]
      target = targetFor(step)
      if (target) break
      pointer += direction
    }

    if (!target) return false

    this.clearHighlight()
    this.index = pointer
    this.step = step
    this.target = target
    this.ensurePanel()
    this.target.scrollIntoView({ block: "center", inline: "nearest" })
    this.target.classList.add(...this.highlightClasses)
    this.target.setAttribute("data-turbo-tour-active", "true")
    this.render()
    this.position()
    this.panel.focus()
    if (emitStart) this.emit("turbo-tour:start")
    return true
  }

  ensurePanel() {
    if (this.panel) return
    if (!this.template) throw new Error("TurboTour template not found")

    this.element.appendChild(this.template.content.cloneNode(true))
    this.panel = this.element.querySelector("[data-turbo-tour-panel]")
    this.title = this.element.querySelector("[data-turbo-tour-title]")
    this.body = this.element.querySelector("[data-turbo-tour-body]")
    this.progress = this.element.querySelector("[data-turbo-tour-progress]")
    this.prevButton = this.element.querySelector("[data-turbo-tour-prev]")
    this.nextButton = this.element.querySelector("[data-turbo-tour-next]")
    this.skipButton = this.element.querySelector("[data-turbo-tour-skip]")

    const id = `turbo-tour-${Math.random().toString(36).slice(2)}`
    if (this.title && !this.title.id) this.title.id = `${id}-title`
    if (this.body && !this.body.id) this.body.id = `${id}-body`
    if (this.title) this.panel.setAttribute("aria-labelledby", this.title.id)
    if (this.body) this.panel.setAttribute("aria-describedby", this.body.id)
  }

  render() {
    const current = this.index + 1
    if (this.title) this.title.textContent = this.step.title
    if (this.body) this.body.innerHTML = this.step.body
    if (this.progress) {
      const progressTemplate = this.translations.progress
      if (progressTemplate) this.progress.textContent = progressTemplate.replace("%{current}", current).replace("%{total}", this.steps.length)
    }

    if (this.prevButton) {
      const disabled = this.index === 0
      this.prevButton.disabled = disabled
      this.prevButton.setAttribute("aria-disabled", String(disabled))
    }

    if (this.nextButton) {
      const finishLabel = this.translations.finish
      const nextLabel = this.translations.next
      if (finishLabel && nextLabel) this.nextButton.textContent = this.index === this.steps.length - 1 ? finishLabel : nextLabel
    }

    if (this.skipButton) {
      this.skipButton.hidden = !this.skippable
      this.skipButton.disabled = !this.skippable
      this.skipButton.setAttribute("aria-hidden", String(!this.skippable))
      this.skipButton.setAttribute("aria-disabled", String(!this.skippable))
    }

    const preset = SIZE_PRESETS[this.step.size || this.tooltipSize]
    if (preset) {
      this.panel.style.width = preset.width
      this.panel.style.maxHeight = preset.maxHeight
      if (this.body) this.body.style.overflowY = "auto"
    } else {
      this.panel.style.width = ""
      this.panel.style.maxHeight = ""
      if (this.body) this.body.style.overflowY = ""
    }
  }

  position() {
    if (!this.panel || !this.target) return

    const anchor = this.target.getBoundingClientRect()
    const panel = this.panel.getBoundingClientRect()
    const idealLeft = anchor.left + (anchor.width / 2) - (panel.width / 2)
    const maxLeft = window.innerWidth - panel.width - PAD
    const left = Math.min(Math.max(PAD, idealLeft), Math.max(PAD, maxLeft))
    const below = anchor.bottom + GAP
    const above = anchor.top - panel.height - GAP
    const top = below + panel.height <= window.innerHeight - PAD ? below : Math.max(PAD, above)

    this.panel.style.left = `${Math.round(left)}px`
    this.panel.style.top = `${Math.round(top)}px`
  }

  clearHighlight() {
    if (!this.target) return
    this.target.classList.remove(...this.highlightClasses)
    this.target.removeAttribute("data-turbo-tour-active")
    this.target = null
  }

  keydown(event) {
    if (!this.activeJourney || event.altKey || event.ctrlKey || event.metaKey) return
    if (event.key === "ArrowRight") { event.preventDefault(); this.next() }
    if (event.key === "ArrowLeft") { event.preventDefault(); this.previous() }
    if (this.skippable && event.key === "Escape") { event.preventDefault(); this.skip() }
  }

  end({ eventName = null, reason = null, emit = true, restoreFocus = true } = {}) {
    if (!this.activeJourney) return
    if (emit && eventName) this.emit(eventName, { reason, completed: reason === "completed" })

    this.clearHighlight()
    this.panel?.remove()
    sessionStorage.removeItem(this.storageKey)

    const focusTarget = this.lastFocus
    this.activeJourney = null
    this.steps = null
    this.step = null
    this.index = -1
    this.skippable = this.skippableDefault
    this.session = null
    this.lastFocus = null
    this.panel = null
    this.title = null
    this.body = null
    this.progress = null
    this.prevButton = null
    this.nextButton = null
    this.skipButton = null

    if (restoreFocus && focusTarget?.focus) focusTarget.focus()
  }

  emit(name, extra = {}) {
    const detail = this.payload(extra)

    document.dispatchEvent(new CustomEvent(name, { detail }))
    window.TurboTour?.runHooks?.(name, this.hookContext(name, detail))
    return detail
  }

  payload(extra = {}) {
    const total = this.steps?.length || 0
    const progress = total ? Number((((this.index + 1) / total)).toFixed(2)) : 0

    return {
      session_id: this.session,
      journey_name: this.activeJourney,
      step_name: this.step?.name || null,
      step_index: this.index,
      total_steps: total,
      progress,
      progress_percentage: Math.round(progress * 100),
      ...extra
    }
  }

  hookContext(eventName, detail) {
    return {
      eventName,
      completed: Boolean(detail.completed),
      controller: this,
      detail,
      element: this.element,
      journeyName: detail.journey_name,
      panel: this.panel,
      progress: detail.progress,
      progressPercentage: detail.progress_percentage,
      reason: detail.reason || null,
      sessionId: detail.session_id,
      step: this.step ? { ...this.step } : null,
      stepIndex: detail.step_index,
      stepName: detail.step_name,
      steps: this.steps ? this.steps.map((step) => ({ ...step })) : [],
      target: this.target,
      totalSteps: detail.total_steps
    }
  }
}
