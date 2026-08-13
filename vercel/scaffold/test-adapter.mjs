// Local proof harness. Drives the real Vercel adapter (api/serve.mjs) through
// the same (req, res) contract Vercel's Node runtime calls it with, mounting it
// at the catch-all just like the rewrite in vercel.json does.
//
//     node test-adapter.mjs [port]
import { createServer } from "node:http";
import handler from "./api/serve.mjs";

const server = createServer((req, res) => {
  handler(req, res).catch((err) => {
    console.error("adapter threw:", err);
    res.statusCode = 500;
    res.end();
  });
});

const port = Number(process.argv[2] ?? 3200);
server.listen(port, () => console.log(`koru/vercel adapter on http://localhost:${port}`));
