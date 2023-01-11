import "alpinejs"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import NProgress from "nprogress"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

import * as CampaignEditLiveHooks from "./hooks/campaign-edit-live"
import { CampaignSettingsDialogHook } from "./hooks/campaign-settings-dialog"
import CampaignStatsChartHook from "./hooks/campaign-stats-chart"
import * as DateTimeHooks from "./hooks/date-time"
import { RememberUnsaved } from "./hooks/remember-unsaved"

const Hooks = {
  ...DateTimeHooks,
  ...CampaignEditLiveHooks,
  RememberUnsaved,
  CampaignSettingsDialogHook,
  CampaignStatsChartHook
}

// Make hooks available globally
window.Hooks = Hooks

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      if (from.__x) window.Alpine.clone(from.__x, to)
    }
  }
})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
