/**
 * Context Monitor Hook
 *
 * Watches context window usage and warns when it's getting full.
 * Inspired by GSD's gsd-context-monitor.js, adapted for TCP's harness.
 *
 * Event: PostToolUse
 *
 * At 65% usage: suggests spawning sub-agents for remaining work
 * At 80% usage: strong warning to stop inline work and delegate
 *
 * Install: Add to .claude/settings.json under "hooks"
 *
 * Example .claude/settings.json:
 * {
 *   "hooks": {
 *     "PostToolUse": [
 *       {
 *         "description": "Warns when context window is getting full",
 *         "hooks": [
 *           {
 *             "type": "command",
 *             "command": "node .claude/hooks/context-monitor.js"
 *           }
 *         ]
 *       }
 *     ]
 *   }
 * }
 */

import { readFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

// Read hook input from stdin
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  try {
    const event = JSON.parse(input);

    // Try to read context metrics from the statusline bridge file
    // Claude Code writes session metrics that we can read
    const sessionId = process.env.CLAUDE_SESSION_ID || 'unknown';
    const bridgePath = join(tmpdir(), `claude-ctx-${sessionId}.json`);

    let contextPercent = null;

    try {
      const bridge = JSON.parse(readFileSync(bridgePath, 'utf8'));
      if (bridge.context_used_percent) {
        contextPercent = bridge.context_used_percent;
      }
    } catch {
      // Bridge file doesn't exist yet or can't be read — skip silently.
      // The statusline hook needs to be configured to write this file.
      // Without it, this hook is a no-op (safe degradation).
    }

    if (contextPercent === null) {
      // Fallback: estimate from tool call count in this session
      // This is rough but better than nothing
      const toolCalls = event.session?.tool_call_count || 0;
      if (toolCalls > 40) contextPercent = 80;
      else if (toolCalls > 25) contextPercent = 65;
    }

    if (contextPercent === null) {
      process.exit(0); // Can't determine usage, exit silently
    }

    if (contextPercent >= 80) {
      const message = [
        '--- CONTEXT MONITOR: CRITICAL ---',
        `Context window ~${contextPercent}% used.`,
        '',
        'STOP inline work. For remaining tasks:',
        '1. Use Task tool to spawn sub-agents with fresh context',
        '2. Or start a new session with /start or /execute',
        '',
        'Quality degrades significantly past this point.',
        '---'
      ].join('\n');

      console.log(JSON.stringify({ message }));
    } else if (contextPercent >= 65) {
      const message = [
        '--- CONTEXT MONITOR: WARNING ---',
        `Context window ~${contextPercent}% used.`,
        'Consider spawning sub-agents (Task tool) for the next steps',
        'instead of continuing inline. Each sub-agent gets fresh context.',
        '---'
      ].join('\n');

      console.log(JSON.stringify({ message }));
    }

  } catch {
    // Hook must never block tool execution. Fail silently.
  }

  process.exit(0);
});
