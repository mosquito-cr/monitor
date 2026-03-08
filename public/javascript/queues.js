import EventStream from "./event_stream.js"
import { wsBase } from "./lib/config.js"

const eventStream = new EventStream(`${wsBase}/events`)

eventStream.on("broadcast", message => {
  const parts = message.channel.split(":")
  if (parts[0] === "queue-summary") {
    updateQueueSummary(message.queues)
  }
})

async function updateQueueSummary(queueData) {
  const subqueues = ["dead", "pending", "scheduled", "waiting"]

  for (const queue of queueData) {
    for (const subqueue of subqueues) {
      const name = `${queue.name}.${subqueue}`
      const element = document.querySelector(`[data-queue-name="${name}"]`)
      if (! element) continue
      element.textContent = queue.details[subqueue]
    }
  }
}
