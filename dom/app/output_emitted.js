const __koru_len = { get() { return this.length; }, configurable: true };
Object.defineProperty(String.prototype, "len", __koru_len);
Object.defineProperty(Array.prototype, "len", __koru_len);
// koru/dom |js facet — the host bodies for the events declared in index.k.
// Same facet layout the suite pins in 140_009/140_010: one stem, per-target
// implementation files, merged at import.
// The keyed element registry. A component declaring `key` records what it
// painted; `drop` detaches it. This is the library's own book, never the
// consumer's — an app using the markup surface writes no lookup code at all,
// which is the difference between a DOM library and a DOM convention.
//
// Keyed by whatever the caller supplies. From a store that is a row HANDLE,
// which survives compaction: `take` swap-removes the last row into the freed
// slot, so a row's position changes under it while its handle does not.
const __koru_dom_reg = new Map();
function __koru_dom_track(key, node) {
    __koru_dom_reg.set(key, node);
}
// The library's HOST surface: host code in the same module addresses the
// element a key owns, instead of searching the page for it.
//
// This exists because mutating text in place is still host work. A row's text
// column can be READ from Koru but not EXTENDED — building "old + suffix"
// needs an allocating string instance, since the cheap page-allocated form is
// a read-only view, and on a hot path that is one allocation per row per
// update. Until a text column can grow in place, the read-modify-write lives
// here, and the only thing it needs from the library is WHICH element.
//
// Returns undefined for a key nothing was painted under; a caller that has a
// live handle from the store cannot be in that position.
function koruDomNode(key) {
    return __koru_dom_reg.get(key);
}
// Vehicle |js facet — the host escapes the app carries. Each proc is a leaf
// DOM writer; WHICH rows it touches is decided on the Koru side (store
// sweeps, interceptors, the sel watch). Escaped because of named walls:
//
// make-label — the reference's random three-word label (Main.js:18-73,
//   _random at Main.js:3-5, mirrored exactly). The pick is Math.random
//   (host) and the assembled label cannot live in the store (string columns
//   refused, char[N] has no JS lowering — see main.k header).
//
// swap-rows / select-row — the two host escapes left, and each is left for a
//   NAMED reason rather than by default.
//
//   MARKING IS GONE FROM HERE. A row's text lives in the store, a rule arm
//   writes it (`e.label: "{{ e.label:s }} !!!"`), and `Row-repaint` pushes it
//   back through the same markup that painted it. The component describes the
//   row ONCE and both creating it and updating it fall out of that one
//   description — which is what a markup surface is for, and what every
//   hand-written DOM mutation here was standing in for.
//
//   swap-rows MOVES two elements. That is a change to the PARENT's child
//   order, not to anything a row's markup describes, so no repaint expresses
//   it; a keyed list reorder is its own primitive and does not exist yet.
//
//   select-row sets a class on one row and clears it from another. A class
//   placeholder (`class={{ sel:s }}`) LOOKS like it would make this a store
//   write plus a repaint, exactly like marking. It would not, and the reason
//   is worth writing down: a repaint is addressed by the row's HANDLE, and a
//   click only carries the row's ID — it reads it off the element. Getting
//   from one to the other means a scan of the store per click, or a sweep that
//   repaints every row to change one class. Selecting is at PARITY with
//   hand-written today (1.00x); both routes cost more than the single DOM
//   write it does now. So this is a design question about carrying identity
//   through an event, not a markup spelling — and it is not obviously worth
//   winning.
//
//   make-label is the reference's random three-word label (Main.js:18-73). The
//   pick is Math.random; it stays host by nature, not by gap.
const adjectives = ["pretty", "large", "big", "small", "tall", "short", "long", "handsome", "plain", "quaint", "clean", "elegant", "easy", "angry", "crazy", "helpful", "mushy", "odd", "unsightly", "adorable", "important", "inexpensive", "cheap", "expensive", "fancy"];
const colours = ["red", "yellow", "blue", "green", "pink", "brown", "purple", "brown", "white", "black", "orange"];
const nouns = ["table", "chair", "house", "bbq", "desk", "car", "pony", "cookie", "sandwich", "burger", "pizza", "mouse", "keyboard"];
function domRandom(max) {
    return Math.round(Math.random() * 1000) % max;
}
function domRow(id) {
    return document.querySelector("tr[data-id='" + id + "']");
}
const __koru_dom_tpl_Row_0 = (() => { const t = document.createElement("template"); t.innerHTML = "<tr><td class=\"col-md-1\"></td><td class=\"col-md-4\"><a data-action=\"8\"></a></td><td class=\"col-md-1\"><a data-action=\"7\"><span class=\"glyphicon glyphicon-remove\" aria-hidden=\"true\"></span></a></td><td class=\"col-md-6\"></td></tr>"; return t.content.firstChild; })();
let __koru_store_rows = {
  id: new Array(16384).fill(0),
  pos: new Array(16384).fill(0),
  label: new Array(16384).fill(""),
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
let __koru_store_cnt = { n: 0 };
let __koru_store_op = { code: 0, a: 0, b: 0, ida: 0, idb: 0 };
let __koru_store_sel = { cur: 0 };
const main_module = {
  make_label_event: {
    handler(__koru_input) {
      return adjectives[domRandom(adjectives.length)] + " " + colours[domRandom(colours.length)] + " " + nouns[domRandom(nouns.length)];
    },
  },
  select_row_event: {
    handler(__koru_input) {
      const id = __koru_input.id;
      const prev = document.querySelector("tr.danger");
      if (prev !== null) prev.className = "";
      domRow(id).className = "danger";
    },
  },
  swap_rows_event: {
    handler(__koru_input) {
      const a = __koru_input.a;
      const b = __koru_input.b;
      const ta = domRow(a);
      const tb = domRow(b);
      const parent = ta.parentNode;
      const afterB = tb.nextSibling;
      parent.insertBefore(tb, ta);
      parent.insertBefore(ta, afterB === ta ? tb : afterB);
    },
  },
  clear_event: {
    handler(__koru_input) {
      {
        for (let __koru_i = 0; __koru_i < __koru_store_rows.__koru_hslot_next; __koru_i++) {
        __koru_store_rows.__koru_hslot_gen[__koru_i] += 1;
        }
        __koru_store_rows.len = 0;
        __koru_store_rows.__koru_hslot_free_len = 0;
        __koru_store_rows.__koru_hslot_next = 0;
        main_module.__store_cleared_rows_0_event.handler({});
      }
    },
  },
  build_event: {
    handler(__koru_input) {
      const n = __koru_input.n;
for (let __koru_item = 0; __koru_item < n; __koru_item++) {
        { const _auto_0 = __koru_item;         const l = main_module.make_label_event.handler({});
        const result_0 = main_module.__store_insertf_rows_event.handler({ id: __koru_store_seq.next, pos: __koru_store_cnt.n, label: l, __site_line: 98 });
        if (result_0.tag === "row") {
          const _auto_1 = result_0.row;
          main_module.__store_write_seq_event.handler({ field: 0, value: __koru_store_seq.next + 1 });
          main_module.__store_write_cnt_event.handler({ field: 0, value: __koru_store_cnt.n + 1 });
        }
        if (result_0.tag === "full") {
        }
 }
        
    }
    },
  },
  Row_event: {
    handler(__koru_input) {
      const parent = __koru_input.parent;
      const key = __koru_input.key;
      const id = __koru_input.id;
      const label = __koru_input.label;
      const __root = __koru_dom_tpl_Row_0.cloneNode(true);
      __root.setAttribute("data-id", String(id));
      __root.children[0].textContent = String(id);
      __root.children[1].children[0].setAttribute("data-id", String(id));
      __root.children[1].children[0].textContent = String(label);
      __root.children[2].children[0].setAttribute("data-id", String(id));
      document.querySelector(parent).appendChild(__root);
      __koru_dom_track(key, __root);
    },
  },
  Row_repaint_event: {
    handler(__koru_input) {
      const key = __koru_input.key;
      const id = __koru_input.id;
      const label = __koru_input.label;
      const __root = __koru_dom_reg.get(key);
      if (__root === undefined) return;
      __root.setAttribute("data-id", String(id));
      __root.children[0].textContent = String(id);
      __root.children[1].children[0].setAttribute("data-id", String(id));
      __root.children[1].children[0].textContent = String(label);
      __root.children[2].children[0].setAttribute("data-id", String(id));
    },
  },
  __store_insertf_rows_event: {
    handler(__koru_input) {
      const id = __koru_input.id;
      const pos = __koru_input.pos;
      const label = __koru_input.label;
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
      __koru_store_rows.pos[__koru_new_row] = pos;
      __koru_store_rows.label[__koru_new_row] = label.slice(0, 40);
      __koru_store_rows.len += 1;
      main_module.__store_inserted_rows_0_event.handler({ id: id, label: label, h: __koru_store_rows.__koru_handle_of(__koru_new_row) });
      if (__site_line > 104) {
      main_module.__store_qrow_rows_L104_event.handler({ row: __koru_new_row });
      }
      if (__site_line > 113) {
      main_module.__store_qrow_rows_L113_event.handler({ row: __koru_new_row });
      }
      return { tag: "row", row: __koru_store_rows.__koru_handle_of(__koru_new_row) };
    },
  },
  __store_apply_rows_event: {
    handler(__koru_input) {
      const row = __koru_input.row;
      const field = __koru_input.field;
      const value_0 = __koru_input.value_0;
      const value_1 = __koru_input.value_1;
      const value_2 = __koru_input.value_2;
      const __koru_r = row;
      switch (field) {
      case 0: { __koru_store_rows.id[__koru_r] = value_0; return { tag: "id", id: value_0 }; }
      case 1: { __koru_store_rows.pos[__koru_r] = value_1; return { tag: "pos", pos: value_1 }; }
      case 2: { __koru_store_rows.label[__koru_r] = value_2.slice(0, 40); return { tag: "label", label: value_2 }; }
      }
      throw new Error("__store_apply_rows: field index " + field + " is not a column of store 'rows'");
    },
  },
  __store_write_rows_event: {
    handler(__koru_input) {
      const row = __koru_input.row;
      const field = __koru_input.field;
      const value_0 = __koru_input.value_0;
      const value_1 = __koru_input.value_1;
      const value_2 = __koru_input.value_2;
      const result_1 = main_module.__store_apply_rows_event.handler({ row: row, field: field, value_0: value_0, value_1: value_1, value_2: value_2 });
      if (result_1.tag === "id") {
        const _auto_3 = result_1.id;
      }
      if (result_1.tag === "pos") {
        const _auto_4 = result_1.pos;
      }
      if (result_1.tag === "label") {
        const _auto_5 = result_1.label;
      }
    },
  },
  __store_qrow_rows_L104_event: {
    handler(__koru_input) {
      const row = __koru_input.row;
      const __koru_r = row;
      const pos = __koru_store_rows.pos[__koru_r];
      const h = __koru_store_rows.__koru_handle_of(__koru_r);
      if (!(((((pos) % (10)) + (10)) % (10)) == 0)) return;
      main_module.__store_qbody_rows_L104_event.handler({ pos: pos, __koru_qrow: __koru_store_rows.__koru_handle_of(__koru_r) , h: h });
      return;
    },
  },
  __store_qbody_rows_L104_event: {
    handler(__koru_input) {
      const pos = __koru_input.pos;
      const __koru_qrow = __koru_input.__koru_qrow;
      const h = __koru_input.h;
if (__koru_store_op.code == 4) {
        {         const __koru_tmpl_1 = "" + ((__koru_store_rows.label)[__koru_store_rows.__koru_resolve(__koru_qrow)]) + " !!!";
        main_module.__store_write_rows_event.handler({ row: ((__koru_store_rows.__koru_resolve(__koru_qrow))), field: 2, value_0: 0, value_1: 0, value_2: __koru_tmpl_1 });
        main_module.Row_repaint_event.handler({ key: h, id: (__koru_store_rows.id)[__koru_store_rows.__koru_resolve(__koru_qrow)], label: (__koru_store_rows.label)[__koru_store_rows.__koru_resolve(__koru_qrow)] });
 }
    } else {
        {  }
    }
    },
  },
  __store_qsweep_rows_L104_event: {
    handler(__koru_input) {
      let __koru_i = 0;
      while (__koru_i < __koru_store_rows.len) {
      const __koru_len_before = __koru_store_rows.len;
      main_module.__store_qrow_rows_L104_event.handler({ row: __koru_i });
      if (__koru_store_rows.len >= __koru_len_before) __koru_i += 1;
      }
      return;
    },
  },
  __store_qrow_rows_L113_event: {
    handler(__koru_input) {
      const row = __koru_input.row;
      const __koru_r = row;
      main_module.__store_qbody_rows_L113_event.handler({ __koru_qrow: __koru_store_rows.__koru_handle_of(__koru_r) });
      return;
    },
  },
  __store_qbody_rows_L113_event: {
    handler(__koru_input) {
      const __koru_qrow = __koru_input.__koru_qrow;
if (__koru_store_op.code == 6) {
        { if ((__koru_store_rows.pos)[__koru_store_rows.__koru_resolve(__koru_qrow)] == __koru_store_op.a) {
        {           main_module.__store_write_rows_event.handler({ row: ((__koru_store_rows.__koru_resolve(__koru_qrow))), field: 1, value_0: 0, value_1: __koru_store_op.b, value_2: "" });
          main_module.__store_write_op_event.handler({ field: 3, value: (__koru_store_rows.id)[__koru_store_rows.__koru_resolve(__koru_qrow)] });
 }
    } else {
        { if ((__koru_store_rows.pos)[__koru_store_rows.__koru_resolve(__koru_qrow)] == __koru_store_op.b) {
        {             main_module.__store_write_rows_event.handler({ row: ((__koru_store_rows.__koru_resolve(__koru_qrow))), field: 1, value_0: 0, value_1: __koru_store_op.a, value_2: "" });
            main_module.__store_write_op_event.handler({ field: 4, value: (__koru_store_rows.id)[__koru_store_rows.__koru_resolve(__koru_qrow)] });
 }
    } else {
        {  }
    }
 }
    }
 }
    } else {
        { if (__koru_store_op.code == 7) {
        { if ((__koru_store_rows.id)[__koru_store_rows.__koru_resolve(__koru_qrow)] == __koru_store_op.a) {
        {             main_module.__store_write_op_event.handler({ field: 2, value: (__koru_store_rows.pos)[__koru_store_rows.__koru_resolve(__koru_qrow)] });
            const result_2 = main_module.__store_take_rows_event.handler({ row: __koru_qrow });
            const _auto_6 = result_2.item;
 }
    } else {
        {  }
    }
 }
    } else {
        { if (__koru_store_op.code == 77) {
        { if ((__koru_store_rows.pos)[__koru_store_rows.__koru_resolve(__koru_qrow)] > __koru_store_op.b) {
        {               main_module.__store_write_rows_event.handler({ row: ((__koru_store_rows.__koru_resolve(__koru_qrow))), field: 1, value_0: 0, value_1: (__koru_store_rows.pos)[__koru_store_rows.__koru_resolve(__koru_qrow)] - 1, value_2: "" });
 }
    } else {
        {  }
    }
 }
    } else {
        {  }
    }
 }
    }
 }
    }
    },
  },
  __store_qsweep_rows_L113_event: {
    handler(__koru_input) {
      let __koru_i = 0;
      while (__koru_i < __koru_store_rows.len) {
      const __koru_len_before = __koru_store_rows.len;
      main_module.__store_qrow_rows_L113_event.handler({ row: __koru_i });
      if (__koru_store_rows.len >= __koru_len_before) __koru_i += 1;
      }
      return;
    },
  },
  __store_take_rows_event: {
    handler(__koru_input) {
      const row = __koru_input.row;
      const __koru_r = __koru_store_rows.__koru_row_of(row);
      if (__koru_r === null) return { tag: "empty", empty: {} };
      const __koru_gone_slot = __koru_store_rows.__koru_row_hslot[__koru_r];
      const __koru_out_id = __koru_store_rows.id[__koru_r];
      const __koru_out_pos = __koru_store_rows.pos[__koru_r];
      const __koru_out_label = __koru_store_rows.label[__koru_r];
      main_module.__store_removed_rows_0_event.handler({ h: __koru_store_rows.__koru_handle_of(__koru_r) });
      const __koru_last = __koru_store_rows.len - 1;
      if (__koru_r != __koru_last) {
      __koru_store_rows.id[__koru_r] = __koru_store_rows.id[__koru_last];
      __koru_store_rows.pos[__koru_r] = __koru_store_rows.pos[__koru_last];
      __koru_store_rows.label[__koru_r] = __koru_store_rows.label[__koru_last];
      const __koru_mv_slot = __koru_store_rows.__koru_row_hslot[__koru_last];
      __koru_store_rows.__koru_hslot_row[__koru_mv_slot] = __koru_r;
      __koru_store_rows.__koru_row_hslot[__koru_r] = __koru_mv_slot;
      }
      __koru_store_rows.len = __koru_last;
      __koru_store_rows.__koru_hslot_gen[__koru_gone_slot] += 1;
      __koru_store_rows.__koru_hslot_free[__koru_store_rows.__koru_hslot_free_len] = __koru_gone_slot;
      __koru_store_rows.__koru_hslot_free_len += 1;
      return { tag: "item", item: { id: __koru_out_id, pos: __koru_out_pos, label: __koru_out_label } };
    },
  },
  __store_inserted_rows_0_event: {
    handler(__koru_input) {
      const id = __koru_input.id;
      const label = __koru_input.label;
      const h = __koru_input.h;
      {
        const parent = "#tbody";
        const key = h;
        const __root = __koru_dom_tpl_Row_0.cloneNode(true);
        __root.setAttribute("data-id", String(id));
        __root.children[0].textContent = String(id);
        __root.children[1].children[0].setAttribute("data-id", String(id));
        __root.children[1].children[0].textContent = String(label);
        __root.children[2].children[0].setAttribute("data-id", String(id));
        document.querySelector(parent).appendChild(__root);
        __koru_dom_track(key, __root);
      }
    },
  },
  __store_removed_rows_0_event: {
    handler(__koru_input) {
      const h = __koru_input.h;
      main_module.drop_event.handler({ key: h });
      main_module.__store_write_cnt_event.handler({ field: 0, value: __koru_store_cnt.n - 1 });
    },
  },
  __store_cleared_rows_0_event: {
    handler(__koru_input) {
      main_module.drop_all_event.handler({});
      main_module.__store_write_cnt_event.handler({ field: 0, value: 0 });
    },
  },
  __store_clear_rows_event: {
    handler(__koru_input) {
      for (let __koru_i = 0; __koru_i < __koru_store_rows.__koru_hslot_next; __koru_i++) {
      __koru_store_rows.__koru_hslot_gen[__koru_i] += 1;
      }
      __koru_store_rows.len = 0;
      __koru_store_rows.__koru_hslot_free_len = 0;
      __koru_store_rows.__koru_hslot_next = 0;
      main_module.__store_cleared_rows_0_event.handler({});
    },
  },
  __store_stripe_rows_event: {
    handler(__koru_input) {
      main_module.__store_qsweep_rows_L104_event.handler({});
      main_module.__store_qsweep_rows_L113_event.handler({});
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
      const result_3 = main_module.__store_apply_seq_event.handler({ field: field, value: value });
      const _auto_7 = result_3.next;
    },
  },
  __store_announce_seq_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      return;
    },
  },
  __store_apply_cnt_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      switch (field) {
      case 0: { __koru_store_cnt.n = value; return { tag: "n", n: value }; }
      }
      throw new Error("__store_apply_cnt: field index " + field + " is not a column of store 'cnt'");
    },
  },
  __store_write_cnt_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      const result_4 = main_module.__store_apply_cnt_event.handler({ field: field, value: value });
      const _auto_8 = result_4.n;
    },
  },
  __store_announce_cnt_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      return;
    },
  },
  __store_apply_op_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      switch (field) {
      case 0: { __koru_store_op.code = value; return { tag: "code", code: value }; }
      case 1: { __koru_store_op.a = value; return { tag: "a", a: value }; }
      case 2: { __koru_store_op.b = value; return { tag: "b", b: value }; }
      case 3: { __koru_store_op.ida = value; return { tag: "ida", ida: value }; }
      case 4: { __koru_store_op.idb = value; return { tag: "idb", idb: value }; }
      }
      throw new Error("__store_apply_op: field index " + field + " is not a column of store 'op'");
    },
  },
  __store_write_op_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      const result_5 = main_module.__store_apply_op_event.handler({ field: field, value: value });
      if (result_5.tag === "code") {
        const _auto_9 = result_5.code;
      }
      if (result_5.tag === "a") {
        const _auto_10 = result_5.a;
      }
      if (result_5.tag === "b") {
        const _auto_11 = result_5.b;
      }
      if (result_5.tag === "ida") {
        const _auto_12 = result_5.ida;
      }
      if (result_5.tag === "idb") {
        const _auto_13 = result_5.idb;
      }
    },
  },
  __store_announce_op_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      return;
    },
  },
  __store_apply_sel_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      switch (field) {
      case 0: { __koru_store_sel.cur = value; return { tag: "cur", cur: value }; }
      }
      throw new Error("__store_apply_sel: field index " + field + " is not a column of store 'sel'");
    },
  },
  __store_write_sel_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const value = __koru_input.value;
      const result_6 = main_module.__store_apply_sel_event.handler({ field: field, value: value });
      const c = result_6.cur;
      {
        const id = c;
        const prev = document.querySelector("tr.danger");
        if (prev !== null) prev.className = "";
        domRow(id).className = "danger";
      }
    },
  },
  __store_peek_sel_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      switch (field) {
      case 0: return { tag: "cur", cur: __koru_store_sel.cur };
      }
      throw new Error("__store_peek_sel: field index " + field + " is not a column of store 'sel'");
    },
  },
  __store_announce_sel_event: {
    handler(__koru_input) {
      const field = __koru_input.field;
      const result_7 = main_module.__store_peek_sel_event.handler({ field: field });
      const c = result_7.cur;
      {
        const id = c;
        const prev = document.querySelector("tr.danger");
        if (prev !== null) prev.className = "";
        domRow(id).className = "danger";
      }
    },
  },
  if_event: {
    handler(__koru_input) {
      const expr = __koru_input.expr;
      throw new Error("if: |template| proc is inlined at call sites and must never be called");
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
  drop_event: {
    handler(__koru_input) {
      const key = __koru_input.key;
      const node = __koru_dom_reg.get(key);
      if (node === undefined) return;
      __koru_dom_reg.delete(key);
      if (node.parentNode !== null) node.parentNode.removeChild(node);
    },
  },
  drop_all_event: {
    handler(__koru_input) {
      // Per-node detach, deliberately. A "clear the whole container in one call"
      // path was built and MEASURED AT ZERO: 17.1ms against 16.6ms without it.
      // Reading why is the useful part — the container carries a whitespace text
      // node from the page's own HTML, so the "do we own every child?" test never
      // matched and the fast branch never ran once. It was dead code that
      // benchmarked as noise.
      //
      // Making it fire would mean either taking nodes the library did not create
      // (wrong: a container we do not wholly own is not ours to empty) or walking
      // the children to partition them, which is the scan this whole design
      // exists to delete. What remains is ~3.6ms of a thousand-row clear, and it
      // is honest work: N nodes leave the page, so N detaches happen.
      for (const node of __koru_dom_reg.values()) {
      if (node.parentNode !== null) node.parentNode.removeChild(node);
      }
      __koru_dom_reg.clear();
    },
  },
  flow0() {
    main_module.__store_qsweep_rows_L104_event.handler({});
  },
  flow1() {
    main_module.__store_qsweep_rows_L113_event.handler({});
  },
  flow2() {
    const Handlers_8 = {
      click(__arm_9) {
        {
          const action = __arm_9.action;
          if (action == 1) {
            main_module.clear_event.handler({});
            main_module.build_event.handler({ n: 1000 });
            return;
          }
        }
        {
          const action = __arm_9.action;
          if (action == 2) {
            main_module.clear_event.handler({});
            main_module.build_event.handler({ n: 10000 });
            return;
          }
        }
        {
          const action = __arm_9.action;
          if (action == 3) {
            main_module.build_event.handler({ n: 1000 });
            return;
          }
        }
        {
          const action = __arm_9.action;
          if (action == 4) {
            main_module.__store_write_op_event.handler({ field: 0, value: 4 });
            main_module.__store_stripe_rows_event.handler({});
            main_module.__store_write_op_event.handler({ field: 0, value: 0 });
            return;
          }
        }
        {
          const action = __arm_9.action;
          if (action == 5) {
            main_module.clear_event.handler({});
            return;
          }
        }
        {
          const action = __arm_9.action;
          if (action == 6) {
if (__koru_store_cnt.n > 998) {
        {               main_module.__store_write_op_event.handler({ field: 0, value: 6 });
              main_module.__store_write_op_event.handler({ field: 1, value: 1 });
              main_module.__store_write_op_event.handler({ field: 2, value: 998 });
              main_module.__store_stripe_rows_event.handler({});
              main_module.swap_rows_event.handler({ a: __koru_store_op.ida, b: __koru_store_op.idb });
              main_module.__store_write_op_event.handler({ field: 0, value: 0 });
 }
    } else {
        {  }
    }
            return;
          }
        }
        {
          const action = __arm_9.action;
          const id = __arm_9.id;
          if (action == 7) {
            main_module.__store_write_op_event.handler({ field: 0, value: 7 });
            main_module.__store_write_op_event.handler({ field: 1, value: id });
            main_module.__store_stripe_rows_event.handler({});
            main_module.__store_write_op_event.handler({ field: 0, value: 77 });
            main_module.__store_stripe_rows_event.handler({});
            main_module.__store_write_op_event.handler({ field: 0, value: 0 });
            return;
          }
        }
        {
          const action = __arm_9.action;
          const id = __arm_9.id;
          if (action == 8) {
            main_module.__store_write_sel_event.handler({ field: 0, value: id });
            return;
          }
        }
      },
    };
    main_module.run_event.handler({ title: "Koru-DOM (keyed)" }, Handlers_8);
  },
};
main_module.flow0();
main_module.flow1();
main_module.flow2();
