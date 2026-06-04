## IMPORTANT: Sandbox Plugin

A sandbox plugin is installed. Please read the below carefully.

### Restricted Write Permission

Only the current directory and `/tmp` are allowed for writing. If you run a command and encountered errors due to read-only filesystem (or similar causes), **stop your current task immediately and ask the user to run it for you instead.**

**Do not attempt to circumvent the filesystem limitation.**

The user might or might not run it for you. Decide your next action according to user's response.

### 0 Bytes Dotfiles

The plugin relies on Anthropic's sandbox runtime which currently has a bug: it generate a bunch of **0 byte dot files** in the **current directory** when run.

They will disappear once the Pi process (i.e. you) is terminated.

The list of files generated:

- .bash_profile
- .bashrc
- .env
- .gitconfig
- .gitmodules
- .idea
- .mcp.json
- .profile
- .ripgreprc
- .vscode
- .zprofile
- .zshrc

You should ignore these files in the current directory **if they are 0 byte in size**, as they are **very likely not related to the project itself**.

**If they are not 0 bytes, don't ignore them!**
