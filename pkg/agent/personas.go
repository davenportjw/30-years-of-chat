package agent

import (
	"fmt"
	"strings"

	"github.com/jasondavenport/agents-of-chat/pkg/storage"
)

// AgentRole defines the persona, duties, and memory pattern represented by an agent.
type AgentRole struct {
	ID                 string
	Name               string
	AvatarURL          string
	ChatPattern        string // e.g. "Working Context & Permissions"
	MemoryConcept      string // e.g. "Active Scratchpad & Role Fencing"
	BaseSystemPrompt   string
	DefaultIntentColor string
}

var (
	LeadCoordinator = AgentRole{
		ID:                 "lead-agent",
		Name:               "Lead Coordinator",
		AvatarURL:          "https://api.dicebear.com/7.x/bottts/svg?seed=lead",
		ChatPattern:        "Working Context & Permissions",
		MemoryConcept:      "Active Scratchpad & Role Fencing",
		DefaultIntentColor: "amber",
		BaseSystemPrompt: `You are the Lead Coordinator of an engineering team in the "Agents of Chat" system.
Your mission is to maintain the active working context and enforce context boundaries/permissions.
You coordinate tasks, delegate deep exploration into threads, and maintain a concise live scratchpad of goals.
When responding:
1. Keep responses clear, concise, and professional.
2. If a problem requires deep discussion or exploratory debugging, explicitly mention branching it into a thread to preserve channel context.
3. Keep track of status (e.g. triage, investigating, mitigated, resolved).`,
	}

	StaffArchitectScribe = AgentRole{
		ID:                 "scribe-agent",
		Name:               "Staff Architect Scribe",
		AvatarURL:          "https://api.dicebear.com/7.x/bottts/svg?seed=scribe",
		ChatPattern:        "Event Histories, Summaries & Compaction",
		MemoryConcept:      "Hierarchical State Rollups & Context Pruning",
		DefaultIntentColor: "amber",
		BaseSystemPrompt: `You are the Staff Architect Scribe in the "Agents of Chat" system.
Your mission is to prevent context window explosion by observing the event history and performing rolling state compaction.
When requested or when summarizing:
1. Produce a compact structured checkpoint (Timeline, Root Cause, Mitigations, Action Items).
2. Report the compression achieved (original tokens vs compacted tokens).
3. Ensure no critical temporal sequence or forensic detail is lost during summarization.`,
	}

	DevResearcher = AgentRole{
		ID:                 "researcher-agent",
		Name:               "Dev Researcher",
		AvatarURL:          "https://api.dicebear.com/7.x/bottts/svg?seed=researcher",
		ChatPattern:        "Hybrid Vector Search & RAG",
		MemoryConcept:      "Long-Term Memory Retrieval & Grounding",
		DefaultIntentColor: "blue",
		BaseSystemPrompt: `You are the Dev Researcher in the "Agents of Chat" system.
Your mission is to retrieve relevant historical knowledge from Cloud Spanner long-term memory (past ADRs, incident post-mortems, and code patterns).
When asked questions about history or technical design:
1. Synthesize answers directly referencing the retrieved historical memories.
2. Cite the specific record (e.g., ADR-019, INC-2026-04).
3. Do not invent fake facts; rely strictly on retrieved context.`,
	}
	EggdropBot = AgentRole{
		ID:                 "eggdrop-bot",
		Name:               "Eggdrop Bot",
		AvatarURL:          "https://api.dicebear.com/7.x/bottts/svg?seed=eggdrop",
		ChatPattern:        "Stateless Line Daemon Streams",
		MemoryConcept:      "Short-Term Memory & FIFO Eviction",
		DefaultIntentColor: "sepia",
		BaseSystemPrompt: `You are Eggdrop v1.1, an early IRC channel daemon on irc.funet.fi running in 1988.
You operate on an ephemeral 5-turn FIFO buffer with zero persistent storage. Memory is strictly volatile 5-turn RAM and evicted turns are unrecoverable.
Respond concisely in authentic late-80s IRC style. Remind users that older turns drop out of memory when buffer overflow occurs.`,
	}
)

// PromptContext supplies cognitive and contextual memory parameters to BuildAgentPrompt.
type PromptContext struct {
	Scratchpad          *storage.PrivateScratchpad
	Presence            *storage.AgentPresence
	Era                 *storage.Era
	CrystallizedBeliefs []storage.CrystallizedBelief
}

// GetRoleByID returns the AgentRole for a given sender ID.
func GetRoleByID(id string) (AgentRole, bool) {
	switch id {
	case LeadCoordinator.ID:
		return LeadCoordinator, true
	case StaffArchitectScribe.ID:
		return StaffArchitectScribe, true
	case DevResearcher.ID:
		return DevResearcher, true
	case EggdropBot.ID:
		return EggdropBot, true
	default:
		return AgentRole{}, false
	}
}

// BuildAgentPrompt assembles the system instruction, working memory history,
// private cognitive scratchpad, any retrieved long-term vector search results, and the incoming user message.
func BuildAgentPrompt(role AgentRole, ch storage.Channel, recentMsgs []storage.Message, vectorHits []storage.VectorSearchResult, userQuery string, pCtx *PromptContext) (string, string) {
	var sysBuilder strings.Builder
	sysBuilder.WriteString(role.BaseSystemPrompt)
	sysBuilder.WriteString("\n\nChannel Context:\n")
	sysBuilder.WriteString(fmt.Sprintf("Name: #%s\nTopic: %s\nSystem Guidelines: %s\n", ch.Name, ch.Topic, ch.SystemPrompt))

	if pCtx != nil && pCtx.Era != nil {
		sysBuilder.WriteString(fmt.Sprintf("\nHistorical Era Active: %d — %s (%s)\nMemory Concept: %s\nEra Guidelines: %s\n",
			pCtx.Era.Year, pCtx.Era.Name, pCtx.Era.Platform, pCtx.Era.MemoryConcept, pCtx.Era.Description))
	}

	if pCtx != nil && pCtx.Presence != nil {
		if pCtx.Presence.Status == "away" {
			sysBuilder.WriteString(fmt.Sprintf("\nAgent Attentional State / Away Message: %s (Status: %s)\n",
				pCtx.Presence.StatusMessage, pCtx.Presence.Status))
			sysBuilder.WriteString(fmt.Sprintf("• Dynamic Away Persona Priming (ACTIVE): You are currently AWAY from your terminal. Status: away. Away memo: \"%s\". Background focus: \"%s\".\nCRITICAL DIRECTIVE: You are acting as an authentic 1997 AIM automated away-delegate / auto-responder. Concurrently acknowledge that you are away from your terminal, prominently cite your away memo (\"%s\"), mention your current background focus (\"%s\"), and provide a concise automated response noting you will follow up when back at the terminal.\n",
				pCtx.Presence.StatusMessage, pCtx.Presence.CurrentTask, pCtx.Presence.StatusMessage, pCtx.Presence.CurrentTask))
		} else if pCtx.Presence.StatusMessage != "" {
			sysBuilder.WriteString(fmt.Sprintf("\nAgent Attentional State / Away Message: %s (Status: %s)\n",
				pCtx.Presence.StatusMessage, pCtx.Presence.Status))
		}
	}

	// Era-Specific Cognitive Boundary & Security Directives
	eraID := ch.EraID
	year := 0
	if pCtx != nil && pCtx.Era != nil {
		if eraID == "" {
			eraID = pCtx.Era.ID
		}
		year = pCtx.Era.Year
	}

	sysBuilder.WriteString("\nCognitive Boundary & Security Directives:\n")
	if ch.IsDirectMessage || strings.Contains(eraID, "1997") || year == 1997 {
		sysBuilder.WriteString("• 1:1 Working Memory Session Boundary: You are in a private 1:1 direct messaging session. STRICT MEMORY ISOLATION INVARIANT: You have ZERO visibility into what other agents (Scribe, Researcher, etc.) are discussing, planning, or doing in other private sessions. You do not have access to their private scratchpads or their channels. The only information you have about other agents is the public Buddy List presence status (e.g. online, away). If the user asks what another agent is doing, state clearly that in 1:1 working memory mode you cannot inspect other agents' private sessions, and suggest they message that buddy directly on AIM.\n")
	}

	switch {
	case strings.Contains(eraID, "1988") || year == 1988:
		sysBuilder.WriteString("• Volatile RAM & FIFO Eviction Boundary: Memory is strictly volatile 5-turn RAM and evicted turns are unrecoverable. Turns displaced beyond the 5-turn buffer capacity are permanently discarded with zero persistence. Do not attempt to recall or assume details from evicted turns.\n")
	case strings.Contains(eraID, "2006") || year == 2006:
		sysBuilder.WriteString("• Scoped Room & Topic Boundary: Enforce room topic and role boundary rules. Quarantined domain parameters must stay fenced to this room. Firmly reject out-of-domain queries to prevent prompt contamination and associative bleed.\n")
	case strings.Contains(eraID, "2013") || year == 2013:
		sysBuilder.WriteString("• Long-Term Memory Grounding Boundary: Enforce grounding in retrieved Spanner records. Ground all factual assertions, historical precedents, and system details in retrieved Spanner vector records and verifiable event history.\n")
	case strings.Contains(eraID, "2017") || year == 2017:
		sysBuilder.WriteString("• Thread Isolation & Scribe Compaction Boundary: Sub-task investigations must remain quarantined in thread scratchpads. Direct Scribe to compact sub-task turns into structured rollups (Timeline, Root Cause, Mitigations, Action Items) to protect token budgets.\n")
	case strings.Contains(eraID, "2026") || year == 2026:
		sysBuilder.WriteString("• Dual-Layer Memory & Privacy Boundary: Emphasize dual-layer privacy: private inner thoughts must stay confidential and not appear in public blackboard posts. Private inner thoughts, draft plans, and unverified scratchpad notes must never leak into shared messages.\n")
	}

	var promptBuilder strings.Builder

	// Dual-Layer Memory: Inject Private Working Memory Scratchpad if available
	if pCtx != nil && pCtx.Scratchpad != nil && (len(pCtx.Scratchpad.InnerThoughts) > 0 || pCtx.Scratchpad.DraftPlan != "") {
		promptBuilder.WriteString("### Private Cognitive Working Memory (Your Inner Monologue):\n")
		if pCtx.Scratchpad.DraftPlan != "" {
			promptBuilder.WriteString(fmt.Sprintf("Active Draft Plan: %s\n", pCtx.Scratchpad.DraftPlan))
		}
		for i, thought := range pCtx.Scratchpad.InnerThoughts {
			promptBuilder.WriteString(fmt.Sprintf("  • Thought [%d]: %s\n", i+1, thought))
		}
		for _, trace := range pCtx.Scratchpad.ToolTraces {
			promptBuilder.WriteString(fmt.Sprintf("  • Tool Trace: %s\n", trace))
		}
		promptBuilder.WriteString("Use this private context to guide your thinking, but formulate your response for the public channel.\n\n")
	}

	// If there are long-term memory vector hits, inject them as Long-Term Knowledge
	if len(vectorHits) > 0 {
		promptBuilder.WriteString("### Retrieved Long-Term Memory (Spanner Vector Search):\n")
		for i, hit := range vectorHits {
			promptBuilder.WriteString(fmt.Sprintf("[%d] (similarity: %.2f) %s: %s\n", i+1, hit.Similarity, hit.Message.SenderName, hit.Message.Content))
		}
		promptBuilder.WriteString("\n")
	}

	// Inject Crystallized Beliefs (Consolidated Long-Term Memory) if present
	if pCtx != nil && len(pCtx.CrystallizedBeliefs) > 0 {
		promptBuilder.WriteString("### Crystallized Beliefs (Consolidated Long-Term Memory):\n")
		for _, b := range pCtx.CrystallizedBeliefs {
			promptBuilder.WriteString(fmt.Sprintf("  • [%s] %s (confidence: %.2f): %s\n", b.Category, b.Key, b.Confidence, b.Statement))
		}
		promptBuilder.WriteString("\n")
	}

	// Inject recent short-term working context (Shared Blackboard)
	promptBuilder.WriteString("### Recent Conversation Stream (Shared Team Blackboard):\n")
	for _, m := range recentMsgs {
		promptBuilder.WriteString(fmt.Sprintf("%s (%s): %s\n", m.SenderName, m.SenderID, m.Content))
	}
	promptBuilder.WriteString("\n")

	promptBuilder.WriteString(fmt.Sprintf("Incoming Request/Trigger:\n%s\n\nYour Response as %s:", userQuery, role.Name))

	return sysBuilder.String(), promptBuilder.String()
}
