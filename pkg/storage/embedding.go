package storage

import (
	"math"
	"strings"
)

// GenerateEmbedding generates a 768-dimensional normalized semantic vector embedding
// for a given text. It maps domain terms (languages, infrastructure, security, tools, intents)
// to anchored semantic dimensions with L2 normalization, making it fully compatible with
// BigQuery ML.DISTANCE(embedding, @vector, 'COSINE') and Spanner COSINE_DISTANCE.
func GenerateEmbedding(text string) []float64 {
	const dim = 768
	vec := make([]float64, dim)

	lower := strings.ToLower(strings.TrimSpace(text))
	words := strings.FieldsFunc(lower, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\n' || r == '?' || r == '!' ||
			r == '.' || r == ',' || r == ':' || r == ';' || r == '-' ||
			r == '/' || r == '(' || r == ')' || r == '_'
	})

	if len(words) == 0 {
		vec[0] = 1.0
		return vec
	}

	semanticDomains := map[string][]int{
		// Programming & Language
		"language":          {10, 11, 12, 13},
		"python":            {10, 11, 14},
		"go":                {10, 15},
		"golang":            {10, 15},
		"javascript":        {10, 16},
		"flutter":           {10, 17},
		"dart":              {10, 17},
		"code":              {10, 12},
		"coding":            {10, 12},
		"favorite_language": {10, 11, 12},

		// Roles & Personas
		"role":     {50, 51, 52},
		"job":      {50, 51},
		"work":     {50, 53},
		"lead":     {50, 54},
		"scribe":   {50, 55},
		"engineer": {50, 56},
		"job_role": {50, 51, 52},

		// Cloud & Infrastructure
		"tool":             {150, 151},
		"tools":            {150, 151},
		"database":         {150, 152},
		"bigquery":         {150, 153},
		"terraform":        {150, 154},
		"gcp":              {150, 155},
		"cloud":            {150, 156},
		"run":              {150, 157},
		"container":        {150, 157},
		"preferred_tools":  {150, 151},
		"deployment_stack": {150, 156, 157},

		// Security & Zero Trust
		"security":          {180, 181},
		"adc":               {180, 182},
		"secrets":           {180, 183},
		"auth":              {180, 184},
		"security_policies": {180, 181, 182},
		"scratchpad":        {180, 185},

		// Memory & Vectors
		"vector":           {220, 221},
		"embedding":        {220, 222},
		"dream":            {220, 223},
		"dreaming":         {220, 223},
		"consolidation":    {220, 224},
		"crystalline":       {220, 225},
		"belief":            {220, 225},
		"db_vector_search":  {220, 221, 153},

		// Intent & Trajectory
		"intent":           {250, 251},
		"trajectory":       {250, 252},
		"agreed_guidelines": {250, 253},
	}

	for _, w := range words {
		if dims, ok := semanticDomains[w]; ok {
			for _, idx := range dims {
				if idx < dim {
					vec[idx] += 3.0
				}
			}
		}
		// Hash fallback for unmapped words
		h := fnvHash(w) % dim
		vec[h] += 1.0
	}

	// L2 normalization
	var sumSq float64
	for _, v := range vec {
		sumSq += v * v
	}
	norm := math.Sqrt(sumSq)
	if norm > 0 {
		for i := range vec {
			vec[i] = math.Round((vec[i]/norm)*1000000) / 1000000
		}
	} else {
		vec[0] = 1.0
	}

	return vec
}

func fnvHash(s string) int {
	var h uint32 = 2166136261
	for i := 0; i < len(s); i++ {
		h ^= uint32(s[i])
		h *= 16777619
	}
	return int(h & 0x7FFFFFFF)
}

// CosineDistance64 calculates cosine distance (1.0 - similarity) between two 64-bit float vectors.
func CosineDistance64(v1, v2 []float64) float64 {
	if len(v1) == 0 || len(v2) == 0 || len(v1) != len(v2) {
		return 1.0
	}
	var dot, norm1, norm2 float64
	for i := range v1 {
		dot += v1[i] * v2[i]
		norm1 += v1[i] * v1[i]
		norm2 += v2[i] * v2[i]
	}
	if norm1 == 0 || norm2 == 0 {
		return 1.0
	}
	sim := dot / (math.Sqrt(norm1) * math.Sqrt(norm2))
	dist := 1.0 - sim
	if dist < 0 {
		return 0
	}
	if dist > 2 {
		return 2
	}
	return dist
}
