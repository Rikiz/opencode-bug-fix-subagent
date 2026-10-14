package slice

import "testing"

func TestReverseReturnsReversedCopy(t *testing.T) {
	got := Reverse([]int{1, 2, 3})
	want := []int{3, 2, 1}
	if len(got) != len(want) {
		t.Fatalf("len = %d, want %d", len(got), len(want))
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("got %v, want %v", got, want)
		}
	}
}

func TestReverseDoesNotMutateInput(t *testing.T) {
	in := []int{1, 2, 3}
	Reverse(in)
	if in[0] != 1 || in[1] != 2 || in[2] != 3 {
		t.Fatalf("input was mutated: %v", in)
	}
}

func TestReverseEmpty(t *testing.T) {
	in := []int{}
	got := Reverse(in)
	if len(got) != 0 {
		t.Fatalf("got %v, want empty", got)
	}
	if len(in) != 0 {
		t.Fatalf("input was mutated: %v", in)
	}
}

func TestReverseSingleElement(t *testing.T) {
	in := []int{7}
	got := Reverse(in)
	if len(got) != 1 || got[0] != 7 {
		t.Fatalf("got %v, want [7]", got)
	}
	if in[0] != 7 {
		t.Fatalf("input was mutated: %v", in)
	}
}
