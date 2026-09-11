import koru/vaxis
koru/vaxis:run(title: "t")
! draw _ |> koru/vaxis:render()
! char k when k.ch == 'q' |> koru/vaxis:quit()
| err _ |> koru/vaxis:quit()
