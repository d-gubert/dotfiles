// Terminals layout's bottom bar: one chip per space, its agents' icons with their state on each.
// Click to switch, right-click for its menu.

import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, agents, run, theme, shared, openOverlay } from "herdr";

const C = {
  tray: "#1d1f22",
  chip: "#34373c",
  chipEdge: "#4a4d53",
  hover: "#ffffff07",
  text: "#e8e9eb",
  dim: "#8b8f95",
};

// The same space colors as the spaces sidebar's avatars.
const MARK = { ansi6: "#22a99a", ansi3: "#e3814f", ansi4: "#5b8def", ansi5: "#8b7cf6", ansi2: "#3fae6a", ansi1: "#d9649a" };

function own(el) {
  return el.on_mouse_down("left", (_e, cx) => cx.stop_propagation()).on_mouse_down("right", (_e, cx) => cx.stop_propagation());
}

// The agent's state, drawn on the corner of its icon: working spins, blocked asks, done dots, idle rings.
function badge(t, status) {
  const corner = (el) => el.absolute().bottom(-3).right(-4);
  if (status === "working") return corner(svg("mods/workspace-chrome/spinner.svg").size(10).text_color(t.working).spin(900));
  if (status === "blocked")
    return corner(div().size(11).rounded_full().bg(t.blocked).text_size(8.5).font_bold().text_color(C.tray).flex().items_center().justify_center().child("!"));
  if (status === "done") return corner(div().size(8).rounded_full().border_1().border_color(C.tray).bg(t.done));
  return corner(div().size(7).rounded_full().border(1.5).border_color(t.idle ?? t.dim).bg(C.tray));
}

function agentIcon(t, a) {
  const g = a.program;
  return div()
    .relative()
    .flex_none()
    .size(16)
    .flex()
    .items_center()
    .justify_center()
    .when(Boolean(g?.icon), (el) => el.child(g.tint ? svg(g.icon).size(14).text_color(g.color ?? C.text) : image(g.icon).w(14).h(14)))
    .when(!g?.icon, (el) => el.child(div().size(8).rounded_full().bg(C.dim)))
    .child(badge(t, a.status));
}

export default class SpacesBar extends View {
  render() {
    const t = theme();
    const colors = shared("space.colors") ?? {};
    const all = agents();

    const chip = (s) => {
      const color = colors[s.id] ?? "ansi6";
      const fill = color.startsWith("#") ? color : (MARK[color] ?? t[color]);
      const mine = all.filter((a) => a.space === s.id);
      return own(h_flex())
        .id(`sb-${s.id}`)
        .flex_shrink(1)
        .min_w(0)
        .h_full()
        .px(10)
        .gap(8)
        .items_center()
        .rounded(10)
        .border_1()
        .cursor_pointer()
        .text_size(12.5)
        .when(s.active, (el) => el.bg(C.chip).border_color(C.chipEdge))
        .when(!s.active, (el) => el.border_color("#00000000").hover((st) => st.bg(C.hover)))
        .on_click(() => run("space.select", { id: s.id }))
        .on_mouse_down("right", () => openOverlay({ mod: "menu", kind: "popup", width: 200, height: 260, props: { tab: "space", target: { id: s.id } } }))
        .child(div().flex_none().size(8).rounded_full().bg(fill))
        // The index never truncates; a long name gives way first.
        .child(div().flex_none().text_color(C.dim).child(`[${s.index}]`))
        .child(div().min_w(0).truncate().text_color(s.active ? C.text : "#c4c6ca").child(s.name))
        .when(mine.length > 0, (el) => el.child(h_flex().flex_none().gap(7).pl(2).children(mine.map((a) => agentIcon(t, a)))));
    };

    return h_flex()
      .size_full()
      .gap(6)
      .items_center()
      .child(
        h_flex()
          .flex_shrink(1)
          .min_w(0)
          .h(30)
          .p(3)
          .gap(3)
          .rounded(13)
          .bg(C.tray)
          .children(spaces().map(chip)),
      )
      .child(div().flex_1())
      .child(
        own(div())
          .id("sb-pick")
          .flex_none()
          .p(6)
          .rounded(8)
          .text_color(C.dim)
          .cursor_pointer()
          .hover((st) => st.bg(C.tray).text_color(C.text))
          .on_click(() => openOverlay({ mod: "picker", kind: "popup", at: "top", offset: 40, width: 640, height: 0.8 }))
          .child(svg("mods/spaces-bar/stack.svg").size(15)),
      );
  }
}
