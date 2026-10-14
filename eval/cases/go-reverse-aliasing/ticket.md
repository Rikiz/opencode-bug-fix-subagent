Title: Reverse() mutates the caller's slice even though it is documented not to

Observed:
  in := []int{1, 2, 3}
  out := slice.Reverse(in)
  // in is now []int{3, 2, 1}

  The sort key we compute with Reverse() is correct, but the caller's slice is
  left reversed, which corrupts the request struct that owns it.

Expected:
  Reverse() returns a new slice and leaves the input untouched. Same for the
  empty slice.

Location: `Reverse` is declared once in the repo.
Environment: Go 1.21+, no external modules.
