const __koru_len = { get() { return this.length; }, configurable: true };
Object.defineProperty(String.prototype, "len", __koru_len);
Object.defineProperty(Array.prototype, "len", __koru_len);
// koru/dom |js facet — the host bodies for the events declared in index.k.
// Same facet layout the suite pins in 140_009/140_010: one stem, per-target
// implementation files, merged at import.
// Vehicle |js facet — the two host escapes the app carries, each here
// because a named wall keeps it out of Koru:
//
// make-label — the reference's random three-word label (Main.js:18-73,
//   _random at Main.js:3-5, mirrored exactly). Escaped because the pick is
//   Math.random (host) and the assembled label cannot live in the store
//   (char[N] columns have no JS lowering — see main.k header).
//
// append-row — the krausest row markup (Main.js:7-9 rowTemplate, verbatim).
//   Escaped because Koru has no markup surface on this target yet: the vaxis
//   `component` transform is the porting candidate and is round-2 work.
const rowTemplate = document.createElement("tr");
rowTemplate.innerHTML =
  "<td class='col-md-1'> </td><td class='col-md-4'><a> </a></td><td class='col-md-1'><a><span class='glyphicon glyphicon-remove' aria-hidden='true'></span></a></td><td class='col-md-6'></td>";
const adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
const colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"];
const nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];
function domRandom(max) {
    return Math.round(Math.random() * 1000) % max;
}
let __koru_store_rows = {
  id: new Array(16384).fill(0),
  len: 0,
  __koru_hslot_row: new Array(16384).fill(0),
  __koru_hslot_gen: new Array(16384).fill(0),
  __koru_row_hslot: new Array(16384).fill(0),
  __koru_hslot_free: new Array(16384).fill(0),
  __koru_hslot_free_len: 0,
  __koru_hslot_next: 0,
  __koru_brand: 1,
  __koru_row_of(h) {
    if (h < 0) return null;
    const gen = Math.floor(h / 4294967296);
    const low = h - gen * 4294967296;
    if (Math.floor(low / 16777216) !== this.__koru_brand) return null;
    const slot = low % 16777216;
    if (slot >= this.__koru_hslot_next) return null;
    if (gen !== this.__koru_hslot_gen[slot]) return null;
    return this.__koru_hslot_row[slot];
  },
  __koru_resolve(h) {
    const r = this.__koru_row_of(h);
    // Row 0 is a real row and `null` is the only absence — a
    // truthiness test here would reject the first row of every
    // store.
    if (r !== null) return r;
    if (h >= 0) {
      const gen = Math.floor(h / 4294967296);
      const low = h - gen * 4294967296;
      const slot = low % 16777216;
      if (Math.floor(low / 16777216) === this.__koru_brand && slot < this.__koru_hslot_next && gen !== this.__koru_hslot_gen[slot]) {
        throw new Error("std/store: stale row handle into store 'rows' - the row it addressed was removed (stale-handle trap pinned at 690_115)");
      }
    }
    throw new Error("std/store: 'rows[...]' does not address a row - the value is not a handle this store issued (handles come from `| row` and row cursors)");
  },
  __koru_handle_of(dense) {
    const slot = this.__koru_row_hslot[dense];
    return slot + this.__koru_brand * 16777216 + this.__koru_hslot_gen[slot] * 4294967296;
  },
};
let __koru_store_seq = { next: 1 };
const main_module = {
  make_label_event: {
    handler(__koru_input) {
      return adjectives[domRandom(adjectives.length)] + " " + colours[domRandom(colours.length)] + " " + nouns[domRandom(nouns.length)];
    },
  },
  append_row_event: {
    handler(__koru_input) {
      const id = __koru_input.id;
      const label = __koru_input.label;
      const tr = rowTemplate.cloneNode(true);
      tr.setAttribute("data-id", String(id));
      tr.childNodes[0].textContent = String(id);
      const labelAnchor = tr.childNodes[1].firstChild;
      labelAnchor.textContent = label;
      labelAnchor.setAttribute("data-action", "8");
      labelAnchor.setAttribute("data-id", String(id));
      const removeAnchor = tr.childNodes[2].firstChild;
      removeAnchor.setAttribute("data-action", "7");
      removeAnchor.setAttribute("data-id", String(id));
      document.getElementById("tbody").appendChild(tr);
    },
  },
  build_event: {
    handler(__koru_input) {
      const n = __koru_input.n;
for (let __koru_item = 0; __koru_item < n; __koru_item++) {
        { const _auto_0 = __koru_item;         const result_0 = main_module.__store_insertf_rows_event.handler({ id: __koru_store_seq.next, __site_line: 49 });
        if (result_0.tag === "row") {
          const _auto_1 = result_0.row;
          main_module.__store_write_seq_event.handler({ field: 0, value: __koru_store_seq.next + 1 });
        }
        if (result_0.tag === "full") {
        }
 }
        
    }
    },
  },
  __store_insertf_rows_event: {
    handler(__koru_input) {
      const id = __koru_input.id;
      const __site_line = __koru_input.__site_line;
      if (__koru_store_rows.len >= 16384) return { tag: "full", full: {} };
      if (__koru_store_rows.len >= 16384) throw new Error("std/store: store 'rows' is full (capacity 16384) - declared capacity and the `| full` branch are pinned at 690_011");
      const __koru_new_row = __koru_store_rows.len;
      let __koru_hslot;
      if (__koru_store_rows.__koru_hslot_free_len > 0) {
      __koru_store_rows.__koru_hslot_free_len -= 1;
      __koru_hslot = __koru_store_rows.__koru_hslot_free[__koru_store_rows.__koru_hslot_free_len];
      } else {
      __koru_hslot = __koru_store_rows.__koru_hslot_next;
      __koru_store_rows.__koru_hslot_next += 1;
      }
      __koru_store_rows.__koru_hslot_row[__koru_hslot] = __koru_new_row;
      __koru_store_rows.__koru_row_hslot[__koru_new_row] = __koru_hslot;
      __koru_store_rows.id[__koru_new_row] = id;
      __koru_store_rows.len += 1;
      main_module.__store_inserted_rows_0_event.handler({ id: id });
      return { tag: "row", row: __koru_store_rows.__koru_handle_of(__koru_new_row) };
    },
  },
  __store_apply_rows_event: {
    handler(__koru_input) {
      const row = __koru_input.row;
      const field = __koru_input.field;
      const value_0 = __koru_input.value_0;
      const __koru_r = row;
      switch (field) {
      case 0: { __koru_store_rows.id[__koru_r] = value_0; return { tag: "id", id: value_0 }; }
      }
      throw new Error("__store_apply_rows: field index " + field + " is not a column of store 'rows'");
    },
  },
  __store_inserted_rows_0_event: {
    handler(__koru_input) {
      const id = __koru_input.id;
      const l = main_module.make_label_event.handler({});
      {
        const label = l;
        const tr = rowTemplate.cloneNode(true);
        tr.setAttribute("data-id", String(id));
        tr.childNodes[0].textContent = String(id);
        const labelAnchor = tr.childNodes[1].firstChild;
        labelAnchor.textContent = label;
        labelAnchor.setAttribute("data-action", "8");
        labelAnchor.setAttribute("data-id", String(id));
        const removeAnchor = tr.childNodes[2].firstChild;
        removeAnchor.setAttribute("data-action", "7");
        removeAnchor.setAttribute("data-id", String(id));
        document.getElementById("tbody").appendChild(tr);
      }
    },
  },
  __store_apply_seq_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      switch (field) {
      case 0: { __koru_store_seq.next = value; return { tag: "next", next: value }; }
      }
      throw new Error("__store_apply_seq: field index " + field + " is not a column of store 'seq'");
    },
  },
  __store_write_seq_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      const result_1 = main_module.__store_apply_seq_event.handler({ field: field, value: value });
      const _auto_4 = result_1.next;
    },
  },
  __store_announce_seq_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      return;
    },
  },
  for_event: {
    handler(__koru_input, H) {
      const each = H.each;
      const expr = __koru_input.expr;
      const keep = __koru_input.keep;
      throw new Error("for: |template| proc is inlined at call sites and must never be called");
    },
  },
  run_event: {
    handler(__koru_input, H) {
      const click = H.click;
      const title = __koru_input.title;
      document.title = title;
      document.addEventListener("click", (ev) => {
      const el = ev.target.closest("[data-action]");
      if (el === null) return;
      const action = parseInt(el.getAttribute("data-action"), 10);
      const idAttr = el.getAttribute("data-id");
      const id = idAttr === null ? 0 : parseInt(idAttr, 10);
      click({ action: action, id: id });
      });
    },
  },
  flow0() {
    const Handlers_2 = {
      click(__arm_3) {
        {
          const action = __arm_3.action;
          if (action == 1) {
            main_module.build_event.handler({ n: 1000 });
            return;
          }
        }
        {
          const action = __arm_3.action;
          if (action == 3) {
            main_module.build_event.handler({ n: 1000 });
            return;
          }
        }
      },
    };
    main_module.run_event.handler({ title: "Koru-DOM (keyed)" }, Handlers_2);
  },
};
main_module.flow0();
