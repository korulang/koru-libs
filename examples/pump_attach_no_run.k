// MUST_FAIL probe — attach with no matching run
import koru/vaxis

koru/vaxis(orphan)
! char k when k.ch == 'q' |> koru/vaxis:quit()
