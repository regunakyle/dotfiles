#!/bin/bash

host=(
    "alefragnani.project-manager"
    "ibm.output-colorizer"
    "mikestead.dotenv"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "tomoki1207.pdf"
    "usernamehw.errorlens"
    "vincaslt.highlight-matching-tag"
    "vscode-icons-team.vscode-icons"
    "yoavbls.pretty-ts-errors"
)

extensions=(
    "charliermarsh.ruff"
    "DavidAnson.vscode-markdownlint"
    "dbaeumer.vscode-eslint"
    "eamodio.gitlens"
    "emeraldwalk.runonsave"
    "esbenp.prettier-vscode"
    "foxundermoon.shell-format"
    "ggml-org.llama-vscode"
    "github.vscode-github-actions"
    "Gruntfuggly.todo-tree"
    "james-yu.latex-workshop"
    "mechatroner.rainbow-csv"
    "medo64.render-crlf"
    "Mescius.spreadjs-xlsx-editor"
    "mhutchie.git-graph"
    "ms-azuretools.vscode-containers"
    "ms-python.python"
    "ms-toolsai.datawrangler"
    "ms-toolsai.jupyter"
    "ms-vscode.live-server"
    "mylesmurphy.prettify-ts"
    "redhat.vscode-xml"
    "redhat.vscode-yaml"
    "ryu1kn.partial-diff"
    "streetsidesoftware.code-spell-checker"
    "tamasfe.even-better-toml"
    "tht13.rst-vscode" # Requires python3-docutils
    "timonwong.shellcheck"
    "vitest.explorer"
    "yzhang.markdown-all-in-one"
)

for extension in "${host[@]}" "${extensions[@]}"; do
    code --install-extension "$extension"
done

