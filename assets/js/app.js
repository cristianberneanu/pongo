// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

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
import { Socket } from "phoenix"
import NProgress from "nprogress"
import { LiveSocket } from "phoenix_live_view"

let g_data = null, g_previous_data = null, g_canvas = null, g_context = null;
let g_frames = 0, g_fps_update = performance.now(), g_fps = 0;
let g_updates = 0, g_ups_update = performance.now(), g_ups = 0;
let g_constants = null;

const hitAudio = new Audio("/sounds/hit.wav");

function lerp(start, end, amount) {
  return (1 - amount) * start + amount * end;
}

function paint_info(timestamp) {
  g_frames++;
  const frame_diff = timestamp - g_fps_update;
  if (frame_diff > 1000) {
    g_fps = g_frames * 1000 / frame_diff;
    g_frames = 0;
    g_fps_update += frame_diff;
  }

  const update_diff = timestamp - g_ups_update;
  if (update_diff > 1000) {
    g_ups = g_updates * 1000 / update_diff;
    g_updates = 0;
    g_ups_update += update_diff;
  }

  g_context.textBaseline = "top";
  g_context.font = "12pt monospace";
  g_context.beginPath();
  g_context.fillStyle = "lightgreen";
  g_context.fillText(`ups: ${g_ups.toFixed(1)} fps: ${g_fps.toFixed(1)}`, g_constants.wall_width + 1, 1);
}

function paint_walls() {
  const width = g_constants.field_width, height = g_constants.field_height, size = g_constants.wall_width;
  g_context.fillStyle = "rgba(50, 100, 200, 1)";
  g_context.fillRect(0, 0, size, height);
  g_context.fillRect(width - size, 0, size, height);
}

function paint_ball(lerp_amount) {
  const x = lerp(g_previous_data.ball.x, g_data.ball.x, lerp_amount);
  const y = lerp(g_previous_data.ball.y, g_data.ball.y, lerp_amount);

  g_context.beginPath();
  g_context.fillStyle = "rgba(150, 255, 255, 1)";
  g_context.arc(x, y, g_constants.ball_radius, 0, 2 * Math.PI);
  g_context.fill();
}

function paint_paddles(lerp_amount) {
  const length = g_constants.paddle_length, height = g_constants.paddle_height, thickness = 6;

  g_context.lineJoin = 'bevel';
  g_context.lineWidth = thickness;
  g_context.strokeStyle = 'rgba(100, 255, 255, 1)';

  const player1 = lerp(g_previous_data.player1, g_data.player1, lerp_amount);
  g_context.strokeRect(
    player1 - (length - thickness) / 2,
    g_constants.field_height - height - thickness / 2,
    length - thickness,
    thickness
  );

  const player2 = lerp(g_previous_data.player2, g_data.player2, lerp_amount);
  g_context.strokeRect(
    player2 - (length - thickness) / 2,
    height - thickness / 2,
    length - thickness,
    thickness
  );
}

function paint(timestamp) {
  const lerp_amount = Math.min((timestamp - g_data.timestamp) / g_constants.update_interval, 1);

  g_context.clearRect(0, 0, g_constants.field_width, g_constants.field_height);

  g_context.shadowColor = 'rgba(0, 0, 0, 0)';
  g_context.shadowBlur = 0;

  paint_walls();
  paint_info(timestamp);

  g_context.shadowColor = 'rgba(155, 255, 255, 1)';
  g_context.shadowBlur = 20;

  paint_ball(lerp_amount);
  paint_paddles(lerp_amount);

  requestAnimationFrame(paint);
}

function update() {
  if (g_data.sound) {
    hitAudio.play();
  }
}

const g_hooks = {
  board: {
    mounted() {
      g_canvas = this.el.firstElementChild;
      g_context = g_canvas.getContext("2d");

      g_data = JSON.parse(this.el.dataset.client);
      g_data.timestamp = performance.now();
      g_previous_data = g_data;

      g_constants = JSON.parse(g_canvas.dataset.constants);

      requestAnimationFrame(paint);
    },
    updated() {
      const timestamp = performance.now();

      g_previous_data = g_data;
      g_data = JSON.parse(this.el.dataset.client);
      g_data.timestamp = timestamp;
      g_updates++;

      if (g_data.id != g_previous_data.id) {
        g_previous_data = g_data;
      }

      update();
    }
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: g_hooks })

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
