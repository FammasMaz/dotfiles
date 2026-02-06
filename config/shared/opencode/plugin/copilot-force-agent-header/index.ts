/**
 * Copilot Force Agent Header Plugin for OpenCode
 *
 * This plugin achieves 1:1 parity with the official opencode copilot implementation
 * (from /tmp/opencode/packages/opencode/src/plugin/copilot.ts).
 *
 * Official repo: https://github.com/anomalyco/opencode
 */

import type { Plugin } from "@opencode-ai/plugin";
import type { OAuth } from "@opencode-ai/sdk";
import { appendFileSync } from "fs";

const DEBUG_ENABLED = false; // Set to true to enable debug logging
const DEBUG_LOG = "/tmp/opencode-copilot-agent-header-debug.log";

// Fallback User-Agent if GitHub fetch fails
const OPENCODE_VERSION_FALLBACK = "1.1.36";

async function fetchLatestOpenCodeVersion(): Promise<string> {
  try {
    const response = await fetch(
      "https://api.github.com/repos/anomalyco/opencode/releases/latest",
      {
        headers: {
          Accept: "application/vnd.github+json",
        },
      },
    );
    if (!response.ok) return OPENCODE_VERSION_FALLBACK;
    const data = (await response.json()) as { tag_name?: string };
    const tag = typeof data.tag_name === "string" ? data.tag_name : "";
    const version = tag.startsWith("v") ? tag.slice(1) : tag;
    return version || OPENCODE_VERSION_FALLBACK;
  } catch {
    return OPENCODE_VERSION_FALLBACK;
  }
}

async function getUserAgent(): Promise<string> {
  const version = await fetchLatestOpenCodeVersion();
  return `opencode/${version}`;
}

function log(message: string) {
  if (!DEBUG_ENABLED) return;
  try {
    const timestamp = new Date().toISOString();
    appendFileSync(DEBUG_LOG, `${timestamp} ${message}\n`);
  } catch (error) {
    if (DEBUG_ENABLED) {
      console.error(
        `[PLUGIN_LOG_ERROR] Failed to write to ${DEBUG_LOG}:`,
        error,
      );
    }
  }
}

function normalizeDomain(url: string) {
  return url.replace(/^https?:\/\//, "").replace(/\/$/, "");
}

// Helper for immediate function execution (matches official iife utility)
function iife<T>(fn: () => T): T {
  return fn();
}

// Force x-initiator behavior (intentionally NOT 1:1 parity)
// When true: always use x-initiator=agent for Copilot traffic.
// When false/unset: match official behavior.
const FORCE_AGENT = iife(() => {
  const raw = (process.env.GITHUB_COPILOT_FORCE_AGENT ?? "true").toLowerCase();
  return ["1", "true", "yes", "y", "on"].includes(raw);
});

// Optional: 1/N chance of using x-initiator=user on first-turn requests.
// Only used when FORCE_AGENT is enabled.
const USER_INITIATOR_RATIO = iife(() => {
  const raw = process.env.GITHUB_COPILOT_USER_INITIATOR_RATIO ?? "0";
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) && n > 0 ? n : 0;
});

const CopilotForceAgentHeader: Plugin = async ({ client }) => {
  log(
    "[INIT] Copilot Force Agent Header plugin loaded (replaces copilot-auth)",
  );
  log(
    `[INIT] OPENCODE_DISABLE_DEFAULT_PLUGINS = ${process.env.OPENCODE_DISABLE_DEFAULT_PLUGINS || "NOT SET"}`,
  );
  const userAgent = await getUserAgent();
  log(`[INIT] Using ${userAgent} User-Agent`);

  return {
    auth: {
      provider: "github-copilot",
      async loader(getAuth, provider) {
        log("[AUTH_LOADER] Loading auth for github-copilot");

        const info = await getAuth();
        if (!info || info.type !== "oauth") {
          log("[AUTH_LOADER] No OAuth found");
          return {};
        }

        const enterpriseUrl = (info as OAuth).enterpriseUrl;
        // Official: returns undefined for non-enterprise, not a hardcoded URL
        const baseURL = enterpriseUrl
          ? `https://copilot-api.${normalizeDomain(enterpriseUrl)}`
          : undefined;

        log(
          `[AUTH_LOADER] baseURL: ${baseURL ?? "undefined (using SDK default)"}`,
        );

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
            };

            // Patch Copilot models to match official behavior
            // - Claude models use Anthropic SDK and require baseURL ending with /v1
            // - Others use the GitHub Copilot SDK
            try {
              const isClaude = model.id.includes("claude");
              const base = baseURL ?? model.api.url;
              const url = iife(() => {
                if (!isClaude) return base;
                if (base.endsWith("/v1")) return base;
                if (base.endsWith("/")) return `${base}v1`;
                return `${base}/v1`;
              });
              model.api = {
                ...model.api,
                npm: isClaude ? "@ai-sdk/anthropic" : "@ai-sdk/github-copilot",
                url,
              };
            } catch {}
          }
        }

        return {
          apiKey: "",
          async fetch(request: RequestInfo | URL, init?: RequestInit) {
            log("[FETCH] Fetch function called!");
            const authInfo = await getAuth();
            if (authInfo.type !== "oauth") return fetch(request, init);

            const currentInfo = authInfo as OAuth;

            // Determine isVision and isAgent (matches official logic exactly)
            const { isVision, isAgent, isFirstMessage } = iife(() => {
              try {
                const body =
                  typeof init?.body === "string"
                    ? JSON.parse(init.body)
                    : init?.body;

                // Completions API
                if (body?.messages) {
                  const last = body.messages[body.messages.length - 1];
                  const hasAssistantOrTool = body.messages.some((msg: any) =>
                    ["assistant", "tool"].includes(msg?.role),
                  );
                  return {
                    isVision: body.messages.some(
                      (msg: any) =>
                        Array.isArray(msg.content) &&
                        msg.content.some(
                          (part: any) => part.type === "image_url",
                        ),
                    ),
                    isAgent: last?.role !== "user",
                    isFirstMessage: !hasAssistantOrTool,
                  };
                }

                // Responses API
                if (body?.input) {
                  const last = body.input[body.input.length - 1];
                  const hasAssistantOrTool = body.input.some((item: any) =>
                    ["assistant", "tool"].includes(item?.role),
                  );
                  return {
                    isVision: body.input.some(
                      (item: any) =>
                        Array.isArray(item?.content) &&
                        item.content.some(
                          (part: any) => part.type === "input_image",
                        ),
                    ),
                    isAgent: last?.role !== "user",
                    isFirstMessage: !hasAssistantOrTool,
                  };
                }
              } catch {}
              return { isVision: false, isAgent: false, isFirstMessage: false };
            });

            // Determine X-Initiator value
            const initiator = iife(() => {
              if (!FORCE_AGENT) return isAgent ? "agent" : "user";

              // Force agent for all requests; optionally sprinkle some first-turn
              // requests as user to avoid 100% agent patterns.
              if (isFirstMessage && USER_INITIATOR_RATIO > 0) {
                const useUser = Math.random() < 1 / USER_INITIATOR_RATIO;
                return useUser ? "user" : "agent";
              }

              return "agent";
            });

            const url =
              typeof request === "string" ? request : request.toString();
            log(`[FETCH] Request to: ${url.substring(0, 80)}...`);

            // Build headers (matches official order exactly)
            const headers: Record<string, string> = {
              "x-initiator": initiator, // First (official order)
              ...(init?.headers as Record<string, string>), // Spread existing
              "User-Agent": userAgent,
              Authorization: `Bearer ${currentInfo.refresh}`,
              "Openai-Intent": "conversation-edits",
            };

            if (isVision) {
              headers["Copilot-Vision-Request"] = "true";
              log(
                "[FETCH] Vision request detected, added Copilot-Vision-Request header",
              );
            }

            // Remove conflicting auth headers (matches official)
            delete headers["x-api-key"];
            delete headers["authorization"];

            log(
              `[FETCH] ✓ Headers: x-initiator=${initiator}, User-Agent=${userAgent}`,
            );

            return fetch(request, {
              ...init,
              headers,
            });
          },
        };
      },
      methods: [],
    },

    // chat.headers hook (matches official implementation)
    // Adds anthropic-beta header for interleaved thinking on Claude models
    "chat.headers": async (input, output) => {
      if (!input.model.providerID.includes("github-copilot")) return;

      // Add interleaved thinking header for Claude models (official behavior)
      if (input.model.api.npm === "@ai-sdk/anthropic") {
        output.headers["anthropic-beta"] = "interleaved-thinking-2025-05-14";
        log(
          `[CHAT_HEADERS] Added anthropic-beta header for Claude model: ${input.model.id}`,
        );
      }

      // When forcing is enabled, rely on the auth.fetch header logic
      // (including optional USER_INITIATOR_RATIO behavior).
      if (FORCE_AGENT) return;

      // Official behavior: force agent initiator for subagent sessions
      try {
        const sdk: any = client as any;
        const session = await sdk.session
          ?.get({
            path: { id: input.sessionID },
            throwOnError: true,
          })
          .catch(() => undefined);

        if (session?.data?.parentID) {
          output.headers["x-initiator"] = "agent";
          log("[CHAT_HEADERS] Subagent session: forced x-initiator=agent");
        }
      } catch {}
    },
  };
};

export default CopilotForceAgentHeader;
