// The markup discriminator, both directions (ruled 2026-08-07): lowercase
// tags pass through into the paint template uninspected; a capital tag is a
// call to that component's synthesized event, parent forwarded — an
// invocation graph in the AST, not template text. Pins the mixed path the
// gauntlet vehicle does not exercise: a component whose markup is segments
// (passthrough roots) interleaved with a child component, lowered to an impl
// flow chaining `__Card-seg0(...)` and `Badge(...)` in document order, with
// `text={{ title:s }}` forwarding the parent's prop into the child's input.
import koru/dom

koru/dom:component(Badge) {
    <span class="badge">{{ text:s }}</span>
}

koru/dom:component(Card) {
    <h2 data-kind="card">{{ title:s }}</h2>
    <Badge text={{ title:s }}/>
}

Card(parent: "#main", title: "hello")
