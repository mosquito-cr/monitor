"use strict";

import Executor from './executor.js'
import Nest from './nest.js'

export default class Overseer {
  static template = null

  static setTemplate(elem) {
    Overseer.template = elem
  }

  onMessage(channel, message) {
    this.lastMessageReceivedAt = (new Date()).getTime()

    // overseer message
    if (channel.length == 3) {
      this.overseerMessage(message)
      return
    }

    // queuelist message
    else if (channel.length == 4) { }

    // executor message
    else if (channel.length == 5) {
      this.executorNest
        .findOrHatch(channel[4])
        .onMessage(channel, message)

      this.executorMessage(channel[4], message)
      return
    }
  }

  overseerMessage(message) {
    switch(message.event) {
      case "coordinating":
        this.setCoordinatingFlag(true)
        break
      case "stopping-coordinating":
        this.setCoordinatingFlag(false)
        break
      case "executor-died":
        // { event: "executor-died", executor: "b795db84445aae99" }
        const executor = this.executorNest.findAndRemove(message.executor)
        if (executor)
          executor.blinkAndRemove()
        break
      default:
        console.error(`Unknown overseer message`, message)
    }
  }

  static statusPollInterval = 5000 // ms
  static removeDeadAfter = 30000 // ms an offline overseer stays greyed out

  constructor(overseerId) {
    this.id = overseerId
    this.element = null
    this.updateTimeout = null
    this.removeTimeout = null
    this.onRemove = null

    // Liveness comes from the server's view of the heartbeat, not from
    // websocket traffic: an idle overseer publishes nothing.
    this.alive = null
    this.lastActiveAt = null   // ms, adjusted to the browser clock
    this.lastMessageReceivedAt = (new Date()).getTime()

    this.fetchExecutors()
    this.fetchSelf()
    this.fetchSelfTicker = setInterval(this.fetchSelf.bind(this), Overseer.statusPollInterval)
    this.lastSeenTicker = setInterval(this.updateLastSeen.bind(this), 1000)
  }

  appendTo(element) {
    const template = Overseer.template.content.cloneNode(true)
    template.querySelector(".overseer").dataset.id = this.id
    element.appendChild(template)

    this.element = element.querySelector(`.overseer[data-id="${this.id}"]`)
    this.executorNest = new Nest(this.element.querySelector(".executors tbody"), Executor)

    const shortId = this.element.querySelector('.overseer-id')
    shortId.textContent = `<${this.id.slice(-6)}>`
    shortId.title = this.id

    const fullId = this.element.querySelector('.overseer-full-id')
    fullId.textContent = this.id
    fullId.addEventListener('click', this.copyId.bind(this))

    this.updateSummary()
  }

  copyId(event) {
    const target = event.currentTarget
    navigator.clipboard?.writeText(this.id).then(() => {
      target.classList.add('copied')
      setTimeout(() => target.classList.remove('copied'), 1500)
    }).catch(error => console.error(error))
  }

  // Called when the overseer is no longer in the active list or its status
  // reports it dead. Greys it out, then removes it after a grace period.
  markDead() {
    this.setAlive(false)
    if (this.removeTimeout) return
    this.removeTimeout = setTimeout(this.remove.bind(this), Overseer.removeDeadAfter)
  }

  setAlive(alive) {
    this.alive = alive
    if (alive && this.removeTimeout) {
      clearTimeout(this.removeTimeout)
      this.removeTimeout = null
    }
    this.updateSummary()
  }

  remove() {
    clearInterval(this.fetchSelfTicker)
    clearInterval(this.lastSeenTicker)
    clearTimeout(this.updateTimeout)
    clearTimeout(this.removeTimeout)
    this.element?.remove()
    if (this.onRemove) this.onRemove(this)
  }

  updateLastSeen() {
    if (!this.element) return
    const lastActive = this.element.querySelector('.last-active-at')

    if (this.lastActiveAt == null) {
      lastActive.textContent = this.alive === false ? 'never seen' : ''
      lastActive.classList.toggle('hidden', this.alive !== false)
      return
    }

    const seconds = Math.max(0, Math.round((Date.now() - this.lastActiveAt) / 1000))
    lastActive.textContent = `last seen ${formatAge(seconds)} ago`
    lastActive.title = new Date(this.lastActiveAt).toISOString()
    lastActive.classList.remove('hidden')
  }

  updateSummary() {
    const executorCount = this.executorNest.count
    const busyExecutorCount = Object.values(this.executorNest.hatchlings).filter(executor => executor.busy).length

    const summary = this.element.querySelector(".summary")

    if (busyExecutorCount > 0)
      summary.textContent = `${busyExecutorCount}/${executorCount} busy`
    else
      summary.textContent = `idle`

    if (summary.classList.contains('hidden'))
      summary.classList.remove('hidden')

    const isInactive = this.alive === false
    this.element.classList.toggle('inactive', isInactive)
    this.element.querySelector('.missing').classList.toggle('hidden', !isInactive)

    this.updateLastSeen()
  }

  executorMessage(executorId, message) {
    switch(message.event) {
      case "starting":
        clearTimeout(this.updateTimeout)
        this.updateSummary()
        break

      case "job-finished":
        clearTimeout(this.updateTimeout)
        this.updateTimeout = setTimeout(() => {
          this.updateSummary()
        }, 80)
        break
    }
  }

  async fetchSelf() {
    return fetch(`/api/overseers/${encodeURIComponent(this.id)}`)
    .then(response => response.json())
    .then((overseer) => {
      if (overseer.last_active_at) {
        // Measure age against the server clock so browser clock skew
        // doesn't make a live overseer look stale.
        const age = Date.parse(overseer.server_time) - Date.parse(overseer.last_active_at)
        this.lastActiveAt = Date.now() - age
      } else {
        this.lastActiveAt = null
      }

      if (overseer.alive)
        this.setAlive(true)
      else
        this.markDead()
    }).catch(error => console.error(error))
  }

  async fetchExecutors() {
    fetch(`/api/overseers/${this.id}/executors`)
    .then(response => response.json())
    .then(({executors}) => {
      executors.forEach(executor => {
        this
          .executorNest
          .findOrHatch(executor.id)
          .setState({
            progress: executor.current_job == null ? 0 : 100,
            spin: true,
            job: executor.current_job,
            queue: executor.current_job_queue
          })
      })
      this.updateSummary()
    }).catch(error => console.error(error))
  }
}

function formatAge(seconds) {
  if (seconds < 60) return `${seconds}s`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m ${seconds % 60}s`
  const hours = Math.floor(minutes / 60)
  return `${hours}h ${minutes % 60}m`
}
