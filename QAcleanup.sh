for branch in $FAILED_BRANCHES; do
    echo "Processing branch: '$branch'"
    
    # Debugging merge commits
    echo "Debugging merge commits for $branch:"
    git log --merges --oneline --grep="$branch"
    
    # Find merge commits
    MERGE_COMMITS=$(git log --merges --oneline --grep="$branch" --format="%H")
    if [[ -n "$MERGE_COMMITS" ]]; then
        echo "Found merge commits for $branch: $MERGE_COMMITS"
        for commit in $MERGE_COMMITS; do
            echo "Reverting merge commit: $commit"
            git revert -m 1 "$commit" --no-edit || {
                echo "Conflict occurred while reverting merge commit $commit for $branch. Attempting automatic resolution..."
                git checkout --ours .
                git add .
                git revert --continue || {
                    echo "Failed to resolve conflicts for $commit. Skipping..."
                    git revert --abort
                }
            }
        done
    else
        echo "No merge commits found for branch $branch."
    fi
done
