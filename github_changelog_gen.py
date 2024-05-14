import requests

def get_commits(owner, repo, end_sha=None):
    url = f"https://api.github.com/repos/{owner}/{repo}/commits"
    response = requests.get(url)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Failed to fetch commits: {response.status_code}")
        return None

def generate_changelog(owner, repo, tag_name, end_sha=None):
    commits = get_commits(owner, repo, end_sha)
    if commits:
        changelog = f"* [{tag_name}](https://github.com/{owner}/{repo}/releases/tag/v{tag_name})\n"
        changelog += "    "
        for commit in commits:
            commit_message = commit['commit']['message']
            commit_message = commit_message.split("\n")[0]
            commit_sha = commit['sha']
            if end_sha == commit_sha:
                break
            changelog += f"* [{commit_message}](https://github.com/{owner}/{repo}/commit/{commit_sha})\n    "
        return changelog
    else:
        return "Failed to generate changelog"

if __name__ == "__main__":
    owner = input("Enter the owner of the GitHub repository: ")
    repo = input("Enter the name of the GitHub repository: ")
    tag_name = input("Enter the tag name for the release: ")
    end_sha = input("Enter the ending SHA (optional, leave empty for all commits): ")
    changelog = generate_changelog(owner, repo, tag_name, end_sha)
    print(changelog)
