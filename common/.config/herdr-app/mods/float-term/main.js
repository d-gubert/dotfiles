// A scratch terminal over the tab: `mod.open:float-term` peeks the `float` shell,
// starting it the first time, or closes the peek it opened. The shell keeps running.

import { View, div } from "gpui-kit";
import { exec, focused, terminals, run, props, shared, setShared, closeOverlay } from "herdr";

const NAME = "float";
// Whether the peek is open: no mod API lists overlays, and focused() doesn't report a peek.
const OPEN = "float-term.open";

function shell() {
  return terminals().find((t) => t.name === NAME && t.state !== "finished")?.address;
}

async function peek(cx, self) {
  let t = shell();
  if (!t) {
    const args = ["run", "--bg", "--json", "--no-parent", "--rm", "--name", NAME];
    const cwd = focused()?.cwd;
    if (cwd) args.push("--cwd", cwd);
    t = JSON.parse((await exec("hc", args)).stdout).address;
    // Herdr lists a new terminal a moment after hc run returns.
    for (let i = 0; i < 20 && !shell(); i++) await cx.sleep(50);
  }
  // The launcher holds the keyboard, so it closes before the peek opens. Both run in the
  // same step: after an await, a closed mod's commands do nothing.
  closeOverlay(self);
  run("terminal.peek", { terminal: t });
  setShared(OPEN, true);
}

export default class FloatTerm extends View {
  init(_props, cx) {
    const self = props()?.overlay;
    if (!self) return;
    const t = shell();
    if (t && shared(OPEN)) {
      // Close this launcher first, so overlay.close reaches the peek.
      closeOverlay(self);
      run("overlay.close");
      setShared(OPEN, false);
      return;
    }
    cx.spawn(async (cx) => {
      try {
        await peek(cx, self);
      } catch (e) {
        closeOverlay(self);
        throw e;
      }
    });
  }

  render() {
    return div();
  }
}
