"use strict";

import EventStream from "./event_stream.js"

import Nest from "./nest.js"
import Overseer from "./overseer.js"
import Executor from "./executor.js"

const overseerNest = new Nest(document.querySelector("#overseers"), Overseer)
Overseer.setTemplate(document.querySelector("template#overseer"))

const host = window.location.host
const eventStream = new EventStream(`ws://${host}/events`)

eventStream.on("broadcast", event => {
  const parts = event.channel.split(":")
  switch (parts[1]) {
    case "overseer":
      hatchOverseer(parts[2]).onMessage(parts, event.message)
      break
    case "queue":
      dispatchQueueMessage(parts, event.message)
      break
  }
})

const overseerRefreshInterval = 10000 // ms

function hatchOverseer(overseerId) {
  const overseer = overseerNest.findOrHatch(overseerId)
  overseer.onRemove ||= () => overseerNest.findAndRemove(overseerId)
  return overseer
}

// The server only lists overseers seen within dead_overseer_threshold.
// Add new ones, and grey out (then remove) ones that dropped off the list.
async function fetchOverseers() {
  return fetch("/api/overseers")
  .then(response => response.json())
  .then(({overseers}) => {
    const active = new Set(overseers)

    overseers.forEach(overseerId => hatchOverseer(overseerId).setAlive(true))

    Object.entries(overseerNest.hatchlings).forEach(([overseerId, overseer]) => {
      if (!active.has(overseerId)) overseer.markDead()
    })
  }).catch(error => console.error(error))
}

function go() {
  fetchOverseers()
  setInterval(fetchOverseers, overseerRefreshInterval)
}

if (document.readyState === "loading")
  document.addEventListener("DOMContentLoaded", go)
else
  go()
