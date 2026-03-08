"use strict";

const meta = document.querySelector('meta[name="mosquito-base-path"]')
export const basePath = meta ? meta.content : ""

const host = window.location.host
const wsProtocol = window.location.protocol === "https:" ? "wss:" : "ws:"
export const wsBase = `${wsProtocol}//${host}${basePath}`
