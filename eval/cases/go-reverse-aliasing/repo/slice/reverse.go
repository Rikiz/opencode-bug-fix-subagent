// Package slice holds small slice helpers.
package slice

// Reverse returns a reversed copy of s. The input must not be modified.
func Reverse(s []int) []int {
	out := s[:len(s):len(s)]
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	return out
}
