## IMPORTANT: 0 byte dot files

A sandbox plugin is installed. It relies on Anthropic's sandbox runtime which currently has a bug: it generate a bunch of **0 byte** **dot files** in the current directory when run.

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
