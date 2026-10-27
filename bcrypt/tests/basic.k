// Roundtrip: hash() a password, verify() the digest, verify() a wrong
// password. Cost 4 is bcrypt's minimum — fastest legal work factor; the
// format is identical at every cost, so the surface under test is the same.

import libs/bcrypt
import std/io

libs/bcrypt:hash(password: "secret123456", cost: 4): digest
|> std/io:print.ln("digest        = {{ digest:s }}")
|> libs/bcrypt:verify(password: "secret123456", digest): ok
|> std/io:print.ln("verify right  = {{ ok:any }}")
|> libs/bcrypt:verify(password: "wrong-password", digest): bad
|> std/io:print.ln("verify wrong  = {{ bad:any }}")
