echo "=== TMUX ===" && tmux ls 2>/dev/null || echo "none"
echo "=== SCREEN ===" && screen -ls 2>/dev/null
echo ""
echo "  screen -wipe   = removes dead sessions"
echo "  screen -X quit = kills a live session"
