import koru/mini

koru/mini:greet = koru/mini:greet.default(who, allocator)
| ok _ => ok "OVERRIDDEN greeting"
