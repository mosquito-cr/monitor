import EventStream from "./event_stream.js"
const host = window.location.host
const eventStream = new EventStream(`ws://${host}/events`)
// eventStream.on("message", message => console.log(message))
