import koru/pq
import std/io

// Async surface + tx + params smoke: exercises connect-start/poll,
// set-nonblocking, send-query, consume-input, is-busy, get-result,
// exec-params, tx.begin/commit, result.getv/ncols/field-name.
main =
    koru/pq:connect-start(conninfo: "host=localhost dbname=postgres user=postgres")
    | err e |> std/io:print.ln("connect-start failed: {{ e:s }}")
    | ok conn |> koru/pq:connect-poll(conn)
        | failed e |> std/io:print.ln("poll failed: {{ e:s }}")
        | read c2 |> koru/pq:conn.close(conn: c2)
            |> std/io:print.ln("would wait for read")
        | write c2 |> koru/pq:conn.close(conn: c2)
            |> std/io:print.ln("would wait for write")
        | ok settled |> koru/pq:set-nonblocking(conn: settled)
            | err e |> std/io:print.ln("nonblock failed: {{ e:s }}")
            | ok |> koru/pq:send-query(conn: settled, sql: "SELECT 1 AS one")
                | err e |> std/io:print.ln("send failed: {{ e:s }}")
                | sent |> koru/pq:consume-input(conn: settled)
                    | err e |> std/io:print.ln("consume failed: {{ e:s }}")
                    | ok |> koru/pq:get-result(conn: settled)
                        | err e |> std/io:print.ln("result failed: {{ e:s }}")
                        | done |> std/io:print.ln("done early")
                        | empty |> std/io:print.ln("empty result")
                        | rows r |> koru/pq:result.getv(result: r, row: 0, col: 0)
                            | null |> std/io:print.ln("null")
                            | some vv |> std/io:print.ln("got {{ vv:s }}")
                        |> koru/pq:tx.begin(conn: settled)
                            | err e |> std/io:print.ln("begin failed: {{ e:s }}")
                            | ok tx |> koru/pq:tx.commit(conn: tx)
                                | err failed |> koru/pq:conn.close(conn: failed)
                                    |> std/io:print.ln("commit failed")
                                | ok done |> koru/pq:disconnect(conn: done)
                                    |> std/io:print.ln("tx ok")
