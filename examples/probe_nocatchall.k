import koru/vaxis
koru/vaxis:run(title: "t")
! ready |> koru/vaxis:render()
! key k when k.ch == 'q' |> koru/vaxis:quit()
| err _ |> koru/vaxis:quit()
