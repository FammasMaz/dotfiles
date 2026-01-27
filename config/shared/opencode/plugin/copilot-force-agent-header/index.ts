/**
 * Copilot Force Agent Header Plugin for OpenCode
 *
 * This plugin achieves 1:1 parity with the official opencode copilot implementation
 * (from /tmp/opencode/packages/opencode/src/plugin/copilot.ts) with one modification:
 * - Forces x-initiator to "agent" on all requests (configurable via USER_INITIATOR_RATIO)
 *
 * Official repo: https://github.com/anomalyco/opencode
 */

import type { Plugin } from "@opencode-ai/plugin"
import type { OAuth } from "@opencode-ai/sdk"
import { appendFileSync } from "fs"

const DEBUG_ENABLED = true // Set to true to enable debug logging
const DEBUG_LOG = "/tmp/opencode-copilot-agent-header-debug.log"
const USER_INITIATOR_RATIO = 0 // 1/X chance of "user" for first messages (<=0 disables and always uses "agent")

// Match official opencode User-Agent (update version periodically)
// Latest from: https://github.com/anomalyco/opencode/releases/latest
const OPENCODE_VERSION = "1.1.36"

function log(message: string) {
  if (!DEBUG_ENABLED) return
  try {
    const timestamp = new Date().toISOString()
    appendFileSync(DEBUG_LOG, `${timestamp} ${message}\n`)
  } catch (error) {
    if (DEBUG_ENABLED) {
      console.error(`[PLUGIN_LOG_ERROR] Failed to write to ${DEBUG_LOG}:`, error)
    }
  }
}

function normalizeDomain(url: string) {
  return url.replace(/^https?:\/\//, "").replace(/\/$/, "")
}

// Helper for immediate function execution (matches official iife utility)
function iife<T>(fn: () => T): T {
  return fn()
}

const CopilotForceAgentHeader: Plugin = async ({ client }) => {
  log("[INIT] Copilot Force Agent Header plugin loaded (replaces copilot-auth)")
  log(`[INIT] OPENCODE_DISABLE_DEFAULT_PLUGINS = ${process.env.OPENCODE_DISABLE_DEFAULT_PLUGINS || "NOT SET"}`)
  log(`[INIT] Using opencode/${OPENCODE_VERSION} User-Agent`)

  return {
    auth: {
      provider: "github-copilot",
      async loader(getAuth, provider) {
        log("[AUTH_LOADER] Loading auth for github-copilot")

        const info = await getAuth()
        if (!info || info.type !== "oauth") {
          log("[AUTH_LOADER] No OAuth found")
          return {}
        }

        const enterpriseUrl = (info as OAuth).enterpriseUrl
        // Official: returns undefined for non-enterprise, not a hardcoded URL
        const baseURL = enterpriseUrl
          ? `https://copilot-api.${normalizeDomain(enterpriseUrl)}`
          : undefined

        log(`[AUTH_LOADER] baseURL: ${baseURL ?? "undefined (using SDK default)"}`)

        // Set model costs to 0 (matches official)
        if (provider && provider.models) {
          for (const model of Object.values(provider.models)) {
            model.cost = {
              input: 0,
              output: 0,
              cache: {
                read: 0,
                write: 0,
              },
            }
          }
        }
        // NOTE: Model URL/npm patching removed - let opencode's internal copilot plugin handle it
        // The official does this but it requires internal SDK knowledge we don't have as a plugin

        return {
          apiKey: "",
          async fetch(request: RequestInfo | URL, init?: RequestInit) {
            log("[FETCH] Fetch function called!")
            const authInfo = await getAuth()
            if (authInfo.type !== "oauth") return fetch(request, init)

            const currentInfo = authInfo as OAuth

            // Determine isVision and isAgent (matches official logic exactly)
            const { isVision, isAgent } = iife(() => {
              try {
                const body = typeof init?.body === "string" ? JSON.parse(init.body) : init?.body

                // Completions API
                if (body?.messages) {
                  const last = body.messages[body.messages.length - 1]
                  return {
                    isVision: body.messages.some(
                      (msg: any) =>
                        Array.isArray(msg.content) && msg.content.some((part: any) => part.type === "image_url"),
                    ),
                    isAgent: last?.role !== "user",
                  }
                }

                // Responses API
                if (body?.input) {
                  const last = body.input[body.input.length - 1]
                  return {
                    isVision: body.input.some(
                      (item: any) =>
                        Array.isArray(item?.content) && item.content.some((part: any) => part.type === "input_image"),
                    ),
                    isAgent: last?.role !== "user",
                  }
                }
              } catch {}
              return { isVision: false, isAgent: false }
            })

            // Determine X-Initiator value (our custom logic for forcing agent)
            let initiator: string
            if (isAgent) {
              // Non-first message: always use "agent"
              initiator = "agent"
              log("[FETCH] Non-first message detected, using: agent")
            } else {
              // First message: 1/USER_INITIATOR_RATIO chance of "user", otherwise "agent"
              const userProbability = USER_INITIATOR_RATIO > 0 ? 1 / USER_INITIATOR_RATIO : 0
              const randomValue = Math.random()
              const useUser = randomValue < userProbability
              initiator = useUser ? "user" : "agent"
              const thresholdLog = USER_INITIATOR_RATIO > 0 ? userProbability.toFixed(4) : "disabled"
              log(`[FETCH] First message detected, random=${randomValue.toFixed(4)}, threshold=${thresholdLog}, using: ${initiator}`)
            }

            const url = typeof request === "string" ? request : request.toString()
            log(`[FETCH] Request to: ${url.substring(0, 80)}...`)

            // Build headers (matches official order exactly)
            const headers: Record<string, string> = {
              "x-initiator": initiator, // First (official order)
              ...(init?.headers as Record<string, string>), // Spread existing
              "User-Agent": `opencode/${OPENCODE_VERSION}`,
              Authorization: `Bearer ${currentInfo.refresh}`,
              "Openai-Intent": "conversation-edits",
            }

            if (isVision) {
              headers["Copilot-Vision-Request"] = "true"
              log("[FETCH] Vision request detected, added Copilot-Vision-Request header")
            }

            // Remove conflicting auth headers (matches official)
            delete headers["x-api-key"]
            delete headers["authorization"]

            log(`[FETCH] ✓ Headers: x-initiator=${initiator}, User-Agent=opencode/${OPENCODE_VERSION}`)

            return fetch(request, {
              ...init,
              headers,
            })
          },
        }
      },
      methods: [],
    },

    // chat.headers hook (matches official implementation)
    // Adds anthropic-beta header for interleaved thinking on Claude models
    "chat.headers": async (input, output) => {
      if (!input.model.providerID.includes("github-copilot")) return

      // Add interleaved thinking header for Claude models (official behavior)
      if (input.model.api.npm === "@ai-sdk/anthropic") {
        output.headers["anthropic-beta"] = "interleaved-thinking-2025-05-14"
        log(`[CHAT_HEADERS] Added anthropic-beta header for Claude model: ${input.model.id}`)
      }

      // Force agent initiator for all requests (our custom behavior)
      // This overrides the fetch wrapper's x-initiator for subagent consistency
      output.headers["x-initiator"] = "agent"
      log("[CHAT_HEADERS] Forced x-initiator=agent via chat.headers hook")
    },
  }
}

export default CopilotForceAgentHeader
