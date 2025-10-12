#!/usr/bin/env python3
"""
Analyzes Bazel execution logs to detect non-hermetic build behavior.

This is a Bazel-native approach that doesn't require system tracing tools
or root access. It analyzes the execution_log_json_file to identify
potentially non-hermetic actions.

Usage:
    bazel build --execution_log_json_file=/tmp/exec.log //your:target
    python3 tools/hermetic_test/analyze_exec_log.py /tmp/exec.log
"""

import json
import sys
import os
from pathlib import Path
from collections import defaultdict

# ANSI colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

class HermitricityAnalyzer:
    def __init__(self, workspace_dir):
        self.workspace_dir = Path(workspace_dir).resolve()
        self.suspicious_patterns = [
            '/usr/local/',
            '/opt/homebrew/',
            '/.cargo/',
            '/.rustup/',
            '/go/pkg/',
            '/go/bin/',
            '/.npm/',
            '/.cache/',
        ]

        self.allowed_system_paths = [
            '/usr/bin/env',  # Common for script interpreters
            '/bin/bash',
            '/bin/sh',
            '/usr/lib/',
            '/lib/',
            '/System/Library/',  # macOS
            '/Library/Developer/CommandLineTools/',  # Xcode
        ]

        self.issues = defaultdict(list)
        self.total_actions = 0
        self.analyzed_actions = 0

    def is_suspicious_path(self, path):
        """Check if a path looks non-hermetic."""
        path_str = str(path)

        # Allow Bazel-managed paths
        if 'bazel-' in path_str or '/external/' in path_str:
            return False

        # Allow workspace paths
        if path_str.startswith(str(self.workspace_dir)):
            return False

        # Check for suspicious patterns
        for pattern in self.suspicious_patterns:
            if pattern in path_str:
                return True

        # Check if it's an allowed system path
        for allowed in self.allowed_system_paths:
            if path_str.startswith(allowed):
                return False

        return False

    def analyze_action(self, action):
        """Analyze a single action for hermiticity issues."""
        mnemonic = action.get('mnemonic', 'Unknown')

        # Check commandArgs (the actual field name in Bazel execution log)
        command_args = action.get('commandArgs', action.get('arguments', []))

        # Check all arguments for suspicious paths
        for arg in command_args:
            if self.is_suspicious_path(arg):
                self.issues['suspicious_tool'].append({
                    'mnemonic': mnemonic,
                    'path': arg,
                    'action': action.get('targetLabel', 'Unknown')
                })

        # Check input files
        for input_file in action.get('inputs', []):
            path = input_file.get('path', '')
            if self.is_suspicious_path(path):
                self.issues['suspicious_input'].append({
                    'mnemonic': mnemonic,
                    'path': path,
                    'action': action.get('targetLabel', 'Unknown')
                })

        # Check for absolute paths in command line
        cmdline = ' '.join(command_args)
        if '/usr/local/' in cmdline or '/opt/homebrew/' in cmdline:
            self.issues['absolute_path'].append({
                'mnemonic': mnemonic,
                'cmdline': cmdline[:200],  # Truncate long commands
                'action': action.get('targetLabel', 'Unknown')
            })

    def analyze_log(self, log_file):
        """Analyze the entire execution log."""
        print(f"📊 Analyzing execution log: {log_file}")
        print()

        try:
            with open(log_file, 'r') as f:
                content = f.read()

            # Parse multiple JSON objects from the file
            # Bazel's execution log contains multiple pretty-printed JSON objects
            decoder = json.JSONDecoder()
            idx = 0
            content = content.strip()

            while idx < len(content):
                # Skip whitespace
                while idx < len(content) and content[idx].isspace():
                    idx += 1

                if idx >= len(content):
                    break

                try:
                    action, end_idx = decoder.raw_decode(content, idx)
                    self.total_actions += 1
                    idx = end_idx

                    # Each object in the log represents an action
                    # Check if it has the expected action fields
                    if 'mnemonic' in action or 'commandArgs' in action:
                        self.analyzed_actions += 1
                        self.analyze_action(action)

                except json.JSONDecodeError as e:
                    # If we can't parse, try to skip to the next object
                    print(f"{YELLOW}Warning: Failed to decode JSON at position {idx}: {e}{NC}")
                    print(f"{YELLOW}Context: ...{content[max(0,idx-50):idx+50]}...{NC}")
                    break

        except FileNotFoundError:
            print(f"{RED}Error: Log file not found: {log_file}{NC}")
            print()
            print("Generate an execution log with:")
            print(f"  bazel build --execution_log_json_file={log_file} //your:target")
            sys.exit(1)

        print(f"Analyzed {self.analyzed_actions} actions (total entries: {self.total_actions})")
        print()

    def print_report(self):
        """Print the hermiticity analysis report."""
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("                  HERMITICITY ANALYSIS REPORT")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()

        total_issues = sum(len(issues) for issues in self.issues.values())

        if total_issues == 0:
            print(f"{GREEN}✅ PASSED: No hermiticity issues detected!{NC}")
            print()
            print("All actions appear to use Bazel-managed tools and inputs.")
            return 0

        print(f"{YELLOW}⚠️  WARNING: Found {total_issues} potential hermiticity issue(s){NC}")
        print()

        # Report suspicious tool usage
        if self.issues['suspicious_tool']:
            print(f"{BLUE}Suspicious Tool Usage ({len(self.issues['suspicious_tool'])} instances):{NC}")
            seen = set()
            for issue in self.issues['suspicious_tool']:
                key = (issue['mnemonic'], issue['path'])
                if key not in seen:
                    seen.add(key)
                    print(f"  {RED}•{NC} {issue['mnemonic']}: {issue['path']}")
                    print(f"    Target: {issue['action']}")
            print()

        # Report suspicious inputs
        if self.issues['suspicious_input']:
            print(f"{BLUE}Suspicious Input Files ({len(self.issues['suspicious_input'])} instances):{NC}")
            seen = set()
            for issue in self.issues['suspicious_input']:
                key = (issue['mnemonic'], issue['path'])
                if key not in seen:
                    seen.add(key)
                    print(f"  {RED}•{NC} {issue['mnemonic']}: {issue['path']}")
                    print(f"    Target: {issue['action']}")
            print()

        # Report absolute paths
        if self.issues['absolute_path']:
            print(f"{BLUE}Hardcoded Absolute Paths ({len(self.issues['absolute_path'])} instances):{NC}")
            seen = set()
            for issue in self.issues['absolute_path']:
                key = (issue['mnemonic'], issue['cmdline'])
                if key not in seen:
                    seen.add(key)
                    print(f"  {RED}•{NC} {issue['mnemonic']}")
                    print(f"    Command: {issue['cmdline']}...")
                    print(f"    Target: {issue['action']}")
            print()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print()
        print(f"{YELLOW}Recommendation:{NC}")
        print("Review these issues to ensure the build is truly hermetic.")
        print("Consider using Bazel-managed toolchains instead of system tools.")
        print()

        return total_issues

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <execution_log_json_file>")
        print()
        print("Generate an execution log with:")
        print("  bazel build --execution_log_json_file=/tmp/exec.log //your:target")
        print()
        print("Then analyze it:")
        print(f"  python3 {sys.argv[0]} /tmp/exec.log")
        sys.exit(1)

    log_file = sys.argv[1]
    workspace_dir = os.getcwd()

    analyzer = HermitricityAnalyzer(workspace_dir)
    analyzer.analyze_log(log_file)
    exit_code = analyzer.print_report()

    sys.exit(min(exit_code, 1))  # Return 0 for success, 1 for issues

if __name__ == '__main__':
    main()
