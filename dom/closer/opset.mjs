// The operation set, DERIVED FROM THE REFERENCE — krausest/js-framework-benchmark.
// Nothing here is recalled from memory. Every operation cites the reference file
// and lines it was read from. The reference clone this was derived against is
// recorded by `git -C <clone> rev-parse HEAD` at derivation time (see closer output).
//
// Sources:
//   benchmarksCommon.ts      = webdriver-ts/src/benchmarksCommon.ts      (benchmark ids + descriptions)
//   benchmarksPlaywright.ts  = webdriver-ts/src/benchmarksPlaywright.ts  (click targets + assertions)
//   isKeyed.ts               = webdriver-ts/src/isKeyed.ts               (html structure golden + keyedness criteria)
//   vanillajs index.html     = frameworks/keyed/vanillajs/index.html     (required buttons / page skeleton)
//   vanillajs Main.js        = frameworks/keyed/vanillajs/src/Main.js    (control semantics: id sequence, update stride, swap indices)
//
// Semantics used below and where each came from:
// - Text assertions are CONTAINS on trimmed text (checkElementContainsText usage
//   throughout benchmarksPlaywright.ts).
// - Ids are sequential from 1 per page load, and CONTINUE across creates:
//   benchmarksPlaywright.ts:47,54 compute expected ids as (i*1000+1) across runs;
//   Main.js:65 (`id: this.id++`) is the control implementing it.
// - "every 10th row" means rows 1, 11, ..., 991 (Main.js:76 `i += 10` from 0;
//   benchmarksPlaywright.ts:85,90 assert row 991).
// - Swap is positions 2 and 999 (Main.js:110-114 swaps data[1]/data[998];
//   benchmarksPlaywright.ts:126,133-134 assert rows 2 and 999).
// - Selection is class "danger" on the TR, exactly one selected
//   (benchmarksPlaywright.ts:105-106,111).
// - Remove: clicking td3>a>span of row N shifts the successor into position N
//   (benchmarksPlaywright.ts:162-163).
// - Required buttons #run #runlots #add #update #clear #swaprows:
//   vanillajs index.html:19-34, and every click target in benchmarksPlaywright.ts.

export const OPSET = [
  {
    id: "01_run1k",
    label: "create rows",
    description: "creating 1,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:127-136",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:39-56",
    },
  },
  {
    id: "02_replace1k",
    label: "replace all rows",
    description: "updating all 1,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:137-146",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:58-73",
    },
  },
  {
    id: "03_update10th1k",
    label: "partial update",
    description: "updating every 10th row for 1,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:147-156",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:75-92",
      stride: "frameworks/keyed/vanillajs/src/Main.js:75-80",
    },
  },
  {
    id: "04_select1k",
    label: "select row",
    description: "highlighting a selected row.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:157-166",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:94-113",
    },
  },
  {
    id: "05_swap1k",
    label: "swap rows",
    description: "swap 2 rows for table with 1,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:167-176",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:115-136",
      indices: "frameworks/keyed/vanillajs/src/Main.js:109-115",
    },
  },
  {
    id: "06_remove1k",
    label: "remove row",
    description: "removing one row.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:177-186",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:138-165",
    },
  },
  {
    id: "07_create10k",
    label: "create many rows",
    description: "creating 10,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:187-196",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:168-185",
    },
  },
  {
    id: "08_create1k_after1k",
    label: "append rows to large table",
    description: "appending 1,000 to a table of 1,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:197-206",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:187-206",
    },
  },
  {
    id: "09_clear1k",
    label: "clear rows",
    description: "clearing a table with 1,000 rows.",
    provenance: {
      definition: "webdriver-ts/src/benchmarksCommon.ts:207-216",
      mechanics: "webdriver-ts/src/benchmarksPlaywright.ts:208-227",
    },
  },
  {
    id: "10_html_structure",
    label: "row html structure",
    description:
      "tr children exactly [td,td,a,td,a,span,td]; td classes col-md-1/col-md-4/col-md-1/col-md-6; span.glyphicon.glyphicon-remove with aria-hidden=true.",
    provenance: {
      golden: "webdriver-ts/src/isKeyed.ts:205-249 (checkTRcorrect)",
      sequence: "webdriver-ts/src/isKeyed.ts:273-282 (#add, then check row 1000)",
      rowTemplate: "frameworks/keyed/vanillajs/src/Main.js:7-9",
    },
  },
  {
    id: "11_keyedness",
    label: "keyed division compliance",
    description:
      "swap moves existing TR nodes (no new nodes); re-run replaces >=1000 TRs; remove removes the stored TR node itself.",
    provenance: {
      criteria: "webdriver-ts/src/isKeyed.ts:130-168 (isKeyedRun/isKeyedRemove/isKeyedSwapRow)",
      instrument: "webdriver-ts/src/isKeyed.ts:46-128 (MutationObserver protocol)",
      sequence: "webdriver-ts/src/isKeyed.ts:273-312",
    },
  },
];
