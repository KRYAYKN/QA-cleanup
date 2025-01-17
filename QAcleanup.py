import json
import subprocess
import sys
from typing import Dict, List, Set

class TestResultProcessor:
    def __init__(self, test_report_path: str, qa_branch: str = 'qa'):
        self.test_report_path = test_report_path
        self.qa_branch = qa_branch
        self.failed_features: Set[str] = set()

    def read_test_results(self) -> Dict:
        """Read and parse the JSON test report."""
        try:
            with open(self.test_report_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Error: Test report not found at {self.test_report_path}")
            sys.exit(1)
        except json.JSONDecodeError:
            print(f"Error: Invalid JSON format in test report at {self.test_report_path}")
            sys.exit(1)

    def extract_failed_features(self, test_results: Dict) -> None:
        """Extract feature branch names from failed test cases in the summary."""
        test_cases = test_results.get('summary', {}).get('testCaseSummaryList', [])
        
        for test_case in test_cases:
            if test_case.get('status') == 'fail':
                # Get feature tags from metadata
                tags = test_case.get('metadata', {}).get('tags', [])
                for tag in tags:
                    if tag.startswith('feature/'):
                        self.failed_features.add(tag)
                        print(f"Found failed feature: {tag}")
                        print(f"Error message: {test_case.get('lastErrorStmtMsg', 'No error message available')}")

    def get_feature_commits(self, feature_branch: str) -> List[str]:
        """Get all commits from a feature branch that were merged into QA."""
        try:
            # Get merge base between feature branch and QA branch
            merge_base = subprocess.check_output(
                ['git', 'merge-base', self.qa_branch, feature_branch],
                text=True
            ).strip()

            # Get all commits from feature branch since merge base
            commits = subprocess.check_output(
                ['git', 'log', '--format=%H', f'{merge_base}..{feature_branch}'],
                text=True
            ).splitlines()

            return commits
        except subprocess.CalledProcessError as e:
            print(f"Error getting commits for feature branch {feature_branch}: {e}")
            return []

    def remove_failed_feature_commits(self) -> None:
        """Remove commits from failed feature branches in QA branch."""
        if not self.failed_features:
            print("No failed features found. QA branch remains unchanged.")
            return

        try:
            # Create a temporary branch from current QA state
            subprocess.run(['git', 'checkout', self.qa_branch], check=True)
            subprocess.run(['git', 'checkout', '-b', 'temp_qa_cleanup'], check=True)

            for feature in self.failed_features:
                commits = self.get_feature_commits(feature)
                if commits:
                    print(f"Removing commits from feature: {feature}")
                    for commit in commits:
                        try:
                            # Revert each commit
                            subprocess.run(['git', 'revert', '--no-commit', commit], check=True)
                    
                    # Commit the revert with a meaningful message
                    subprocess.run([
                        'git', 'commit', '-m', 
                        f'Reverted failed feature: {feature} due to failed tests'
                    ], check=True)

            # Force update QA branch
            subprocess.run(['git', 'checkout', self.qa_branch], check=True)
            subprocess.run(['git', 'reset', '--hard', 'temp_qa_cleanup'], check=True)
            
            # Clean up temporary branch
            subprocess.run(['git', 'branch', '-D', 'temp_qa_cleanup'], check=True)
            
            print("Successfully cleaned up QA branch")

        except subprocess.CalledProcessError as e:
            print(f"Error during git operations: {e}")
            print("Rolling back changes...")
            subprocess.run(['git', 'checkout', self.qa_branch], check=True)
            if subprocess.run(['git', 'branch', '-l', 'temp_qa_cleanup']).returncode == 0:
                subprocess.run(['git', 'branch', '-D', 'temp_qa_cleanup'], check=True)

    def print_test_summary(self, test_results: Dict) -> None:
        """Print summary of test results."""
        summary = test_results.get('summary', {})
        print("\nTest Summary:")
        print(f"Total Tests: {summary.get('testcaseCount', 0)}")
        print(f"Passed: {summary.get('pass', 0)}")
        print(f"Failed: {summary.get('fail', 0)}")
        print(f"Not Run: {summary.get('notRun', 0)}")
        print(f"Test Suite: {summary.get('testSuiteName', 'Unknown')}")
        print(f"Created By: {summary.get('createdBy', 'Unknown')}\n")

def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py <test_report.json>")
        sys.exit(1)

    processor = TestResultProcessor(sys.argv[1])
    
    # Process test results
    test_results = processor.read_test_results()
    processor.print_test_summary(test_results)
    processor.extract_failed_features(test_results)
    
    # Print failed features before proceeding
    if processor.failed_features:
        print("\nFailed features found:")
        for feature in processor.failed_features:
            print(f"- {feature}")
        
        # Proceed with cleanup
        proceed = input("\nDo you want to proceed with removing these features from QA branch? (y/n): ")
        if proceed.lower() == 'y':
            processor.remove_failed_feature_commits()
        else:
            print("Operation cancelled by user")
    else:
        print("No failed features found in test results")

if __name__ == "__main__":
    main()