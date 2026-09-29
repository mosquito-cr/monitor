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

function hatchOverseer(overseerId) {
  const overseer = overseerNest.findOrHatch(overseerId)
  overseer.onRemove ||= () => overseerNest.findAndRemove(overseerId)
  return overseer
}

// Loads the overseers alive at page load. After that, new overseers arrive
// over the websocket, and each overseer polls its own status while quiet.
async function fetchOverseers() {
  return fetch("/api/overseers")
  .then(response => response.json())
  .then(({overseers}) => overseers.forEach(hatchOverseer))
  .catch(error => console.error(error))
}

function go() {
  fetchOverseers()
}

if (document.readyState === "loading")
  document.addEventListener("DOMContentLoaded", go)
else
  go()
