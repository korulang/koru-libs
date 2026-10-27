import libs/bcrypt
import std/io

libs/bcrypt:verify(password: "b216501f5bc3417b8200df5c9c6bafdc", digest: "$2a$12$ttvC9K0Tw/x7rw2neCHVBe16dEt6vLqoyEnvixIiFVMK/fNRLAzQG"): a
|> std/io:print.ln("fixture verify = {{ a:any }}")
