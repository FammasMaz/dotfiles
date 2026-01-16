function setup-gh-bot --description "Add GitHub bot secrets to a repo"
    set pem_file "$HOME/.config/github-bot/private-key.pem"
    set temp_dir (mktemp -d)

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
    and gh secret set OPENCODE_MODEL --repo "$1" --body "antigravity/claude-opus-4.5"
    and gh secret set OPENCODE_FAST_MODEL --repo "$1" --body "antigravity/gemini-3-flash"

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
