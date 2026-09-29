package storage

import (
	"fmt"
	"math"
)

// DotProduct calculates the dot product of two float32 slices.
func DotProduct(a, b []float32) (float32, error) {
	if len(a) != len(b) {
		return 0, fmt.Errorf("vector length mismatch: %d != %d", len(a), len(b))
	}
	var sum float32
	for i := range a {
		sum += a[i] * b[i]
	}
	return sum, nil
}

// VectorMagnitude computes the Euclidean L2 norm of a vector.
func VectorMagnitude(v []float32) float32 {
	var sum float64
	for _, val := range v {
		sum += float64(val) * float64(val)
	}
	return float32(math.Sqrt(sum))
}

// CosineSimilarity computes the exact cosine similarity between two vectors:
// similarity = (A · B) / (||A|| * ||B||)
// Range is [-1.0, 1.0]. Returns 0 if either vector has zero magnitude.
func CosineSimilarity(a, b []float32) (float32, error) {
	if len(a) != len(b) {
		return 0, fmt.Errorf("vector dimension mismatch: %d vs %d", len(a), len(b))
	}
	dot, err := DotProduct(a, b)
	if err != nil {
		return 0, err
	}
	magA := VectorMagnitude(a)
	magB := VectorMagnitude(b)
	if magA == 0 || magB == 0 {
		return 0, nil
	}
	sim := dot / (magA * magB)
	if sim > 1.0 {
		sim = 1.0
	} else if sim < -1.0 {
		sim = -1.0
	}
	return sim, nil
}

// CosineDistance computes the cosine distance: 1.0 - CosineSimilarity.
func CosineDistance(a, b []float32) (float32, error) {
	sim, err := CosineSimilarity(a, b)
	if err != nil {
		return 1.0, err
	}
	return 1.0 - sim, nil
}
