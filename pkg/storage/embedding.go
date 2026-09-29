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

// GenerateMessageEmbedding produces a 16-dimensional normalized float32 semantic vector
// matching the prototype vectors in the persistent store. It maps domain terms (cloud infrastructure,
// product stack, architecture, database consistency, incidents, network, and commands) to
// calibrated semantic coordinate spaces with mathematical L2 normalization.
func GenerateMessageEmbedding(text string) []float32 {
	vec := make([]float32, 16)

	lower := strings.ToLower(strings.TrimSpace(text))
	words := strings.FieldsFunc(lower, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\n' || r == '?' || r == '!' ||
			r == '.' || r == ',' || r == ':' || r == ';' || r == '-' ||
			r == '/' || r == '(' || r == ')' || r == '_' || r == '"' || r == '\''
	})

	protoBasic := []float32{0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50}
	if len(words) == 0 {
		res := make([]float32, 16)
		copy(res, protoBasic)
		return res
	}

	protoInc := []float32{0.82, 0.74, 0.21, 0.12, 0.91, 0.15, 0.05, 0.88, 0.79, 0.18, 0.11, 0.85, 0.14, 0.06, 0.83, 0.77}
	protoNet := []float32{0.78, 0.81, 0.19, 0.14, 0.84, 0.22, 0.08, 0.82, 0.85, 0.16, 0.12, 0.81, 0.18, 0.09, 0.79, 0.83}
	protoDB := []float32{0.85, 0.68, 0.25, 0.10, 0.95, 0.11, 0.03, 0.91, 0.72, 0.22, 0.09, 0.89, 0.12, 0.04, 0.88, 0.71}
	protoArch := []float32{0.12, 0.24, 0.88, 0.92, 0.14, 0.86, 0.22, 0.15, 0.22, 0.89, 0.94, 0.12, 0.85, 0.25, 0.18, 0.28}
	protoDBArch := []float32{0.18, 0.29, 0.82, 0.87, 0.21, 0.81, 0.28, 0.21, 0.27, 0.84, 0.89, 0.19, 0.82, 0.31, 0.22, 0.32}
	protoProd := []float32{0.22, 0.15, 0.31, 0.25, 0.12, 0.28, 0.92, 0.88, 0.21, 0.18, 0.32, 0.24, 0.11, 0.29, 0.89, 0.85}

	weights := make(map[string]float32)

	for _, w := range words {
		switch w {
		case "product", "stack", "build", "deploy", "deployment", "cloud", "run", "bigquery", "ga", "launch",
			"microservice", "microservices", "service", "services", "vertex", "gemini", "frontend", "backend",
			"web", "app", "application", "tech", "technology", "release", "ship", "provision":
			weights["prod"] += 2.0
		case "architecture", "rfc", "kafka", "outbox", "2pc", "consensus", "pattern", "ledger", "design",
			"broker", "event", "streaming", "queue", "pubsub":
			weights["arch"] += 2.0
		case "adr", "adr019", "adr-019", "spanner", "transactional", "transaction", "consistency", "idempotency",
			"idempotent", "distributed", "commit", "acid":
			weights["dbarch"] += 2.5
		case "db", "database", "postgres", "sql", "lock", "contention", "pool", "deadlock", "table", "query",
			"tokens", "auth_tokens":
			weights["db"] += 2.0
		case "incident", "outage", "504", "timeout", "latency", "p99", "alert", "postmortem", "failure",
			"degradation", "root", "cause", "error", "down", "crash":
			weights["inc"] += 2.5
		case "network", "proxy", "traffic", "ingress", "gateway", "http", "socket", "dns", "connection":
			weights["net"] += 2.0
		}
	}

	var totalWeight float32
	for _, w := range weights {
		totalWeight += w
	}

	if totalWeight > 0 {
		for i := 0; i < 16; i++ {
			if w, ok := weights["prod"]; ok {
				vec[i] += protoProd[i] * w
			}
			if w, ok := weights["arch"]; ok {
				vec[i] += protoArch[i] * w
			}
			if w, ok := weights["dbarch"]; ok {
				vec[i] += protoDBArch[i] * w
			}
			if w, ok := weights["db"]; ok {
				vec[i] += protoDB[i] * w
			}
			if w, ok := weights["inc"]; ok {
				vec[i] += protoInc[i] * w
			}
			if w, ok := weights["net"]; ok {
				vec[i] += protoNet[i] * w
			}
		}
	} else {
		for i := 0; i < 16; i++ {
			vec[i] = protoBasic[i]
		}
	}

	// Dispersion hash for individual words to give distinct semantic coordinates
	for _, w := range words {
		idx := fnvHash(w) % 16
		vec[idx] += 0.05
	}

	// L2 normalization to unit vector
	var sumSq float64
	for _, val := range vec {
		sumSq += float64(val) * float64(val)
	}
	mag := math.Sqrt(sumSq)
	if mag > 0 {
		for i := range vec {
			vec[i] = float32(math.Round((float64(vec[i])/mag)*1000000) / 1000000)
		}
	} else {
		copy(vec, protoBasic)
	}

	return vec
}
