function setup-gh-bot --description "Add GitHub bot secrets to a repo"
    set pem_file "$HOME/.config/github-bot/private-key.pem"
    set temp_dir (mktemp -d)
    set OPENCODE_PROVIDERS '{"Antigravity":{"name":"Antigravity","npm":"@ai-sdk/openai-compatible","models":{"antigravity/claude-sonnet-4.5":{"name":"Claude 4.5 Sonnet (Reasoning)","limit":{"context":200000,"output":64000},"variants":{"high":{"reasoningEffort":"high"},"medium":{"reasoningEffort":"medium"},"low":{"reasoningEffort":"low"}},"modalities":{"input":["text","image"],"output":["text"]},"cost":{"input":3,"output":15,"cache_read":0.3,"cache_write":3.75}},"antigravity/claude-opus-4.5":{"name":"Claude 4.5 Opus (Reasoning)","limit":{"context":200000,"output":64000},"reasoning":true,"variants":{"xhigh":{"reasoningEffort":"high"}},"modalities":{"input":["text","image"],"output":["text"]},"cost":{"input":5,"output":25,"cache_read":0.5,"cache_write":6.25}},"antigravity/gemini-3-pro-preview":{"name":"Gemini 3 Pro (Reasoning)","limit":{"context":1000000,"output":64000},"modalities":{"input":["text","image"],"output":["text"]},"cost":{"input":5,"output":25,"cache_read":0.5,"cache_write":6.25}}},"options":{"baseURL":"'$PROXY_BASE_URL'","apiKey":"'$PROXY_API_KEY'"}}}'

    echo "📦 Cloning FammasMaz-agent..."
    gh repo clone FammasMaz/FammasMaz-agent "$temp_dir" -- --depth 1
    and echo "📁 Copying .github folder to current directory..."
    and cp -r "$temp_dir/.github" .
    and echo "🧹 Cleaning up temp files..."
    and rm -rf "$temp_dir"
    and echo "🔧 Setting up secrets for $repo..."
    and gh secret set BOT_APP_ID --repo "$1" --body "$BOT_APP_ID"
    and gh secret set BOT_PRIVATE_KEY --repo "$1" < "$pem_file"
    and gh secret set OPENCODE_API_KEY --repo "$1" --body "$PROXY_API_KEY"
    and gh secret set OPENCODE_MODEL --repo "$1" --body "Antigravity/antigravity/claude-opus-4.5"
    and gh secret set OPENCODE_FAST_MODEL --repo "$1" --body "Antigravity/antigravity/gemini-3-pro-preview"
    and gh secret set CUSTOM_PROVIDERS_JSON --repo "$1" --body "$OPENCODE_PROVIDERS"

    and echo "✅ Secrets added to $repo"
    or echo "❌ Failed to add secrets"

    and echo "📤 Committing and pushing .github folder..."
    and git add .github/
    and git commit -m "Add bot workflows"
    and git push

    and echo "⚡ Enabling workflows..."
    and for workflow in (gh workflow list --repo "$1" --json name,id --jq '.[].id')
        gh workflow enable $workflow --repo "$1"
    end
end
