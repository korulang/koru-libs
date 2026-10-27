# @korulang/bcrypt

bcrypt password hashing for Koru — a thin lift over `std.crypto.pwhash.bcrypt`
(no C dependency). Reads and writes the modular-crypt `$2a$`/`$2b$` digest format
that Rails `has_secure_password` (bcrypt-ruby) stores in `password_digest`
columns.

## API

```koru
import libs/bcrypt

// hash(password: string, cost: i32) -> string
//   Fresh `$2b$` digest, random salt, 2^cost rounds. cost must be 4..=31
//   (bcrypt-ruby's accepted range); anything else asserts.
libs/bcrypt:hash(password: "secret123456", cost: 12): digest |> ...

// verify(password: string, digest: string) -> bool
//   true iff the digest is a well-formed bcrypt digest of the password.
//   A malformed digest returns false rather than trapping.
libs/bcrypt:verify(password: "secret123456", digest: digest): ok |> ...
```

Both paths silently truncate passwords at 72 bytes — the behaviour bcrypt-ruby
has always had — so a digest produced here verifies under bcrypt-ruby and
vice versa.

## Tests

```sh
koruc run bcrypt/tests/basic.k               # hash -> verify roundtrip
koruc run bcrypt/tests/rails_known_answer.k  # verifies a real bcrypt-ruby digest
```

`rails_known_answer.k` verifies a digest produced by bcrypt-ruby inside the
once-campfire reference Rails container (see the comment in that file for the
exact source and password).
