import requests

def get_commits(owner, repo):
    url = f"https://api.github.com/repos/{owner}/{repo}/commits"
    headers = {}
    if token:
        headers = {
            "Authorization": f"Bearer {token}"
        }
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Failed to fetch commits: {response.status_code}")
        return None

def generate_changelog(owner, repo, tag_name, start_sha, end_sha):
    commits = get_commits(owner, repo)
    if commits:
        changelog = f"* [{tag_name}](https://github.com/{owner}/{repo}/releases/tag/v{tag_name})\n"
        changelog += "    "
        for commit in commits:
            if start_sha:
                if start_sha != commit['sha']:
                    break
            commit_message = commit['commit']['message']
            commit_message = commit_message.split("\n")[0]
            commit_sha = commit['sha']
            changelog += f"* [{commit_message}](https://github.com/{owner}/{repo}/commit/{commit_sha})\n    "
            if end_sha == commit_sha:
                break
        return changelog
    else:
        return "Failed to generate changelog"

if __name__ == "__main__":
    owner = input("Enter the owner of the GitHub repository: ")
    repo = input("Enter the name of the GitHub repository: ")
    token = input("Enter your GitHub token (optional if the repo is public): ")
    tag_name = input("Enter the tag name for the release: ")
    start_sha = input("Enter the starting SHA (optional, leave empty for the first commit): ")
    end_sha = input("Enter the ending SHA (optional, leave empty for all commits): ")
    changelog = generate_changelog(owner, repo, tag_name, start_sha, end_sha)
    print(changelog)
