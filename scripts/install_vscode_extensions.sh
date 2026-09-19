#!/bin/bash

extensions=(
    "charliermarsh.ruff"
    "DavidAnson.vscode-markdownlint"
    "dbaeumer.vscode-eslint"
    "emeraldwalk.runonsave"
    "esbenp.prettier-vscode"
    "foxundermoon.shell-format"
    "ggml-org.llama-vscode"
    "mechatroner.rainbow-csv"
    "medo64.render-crlf"
    "Mescius.spreadjs-xlsx-editor"
    "mhutchie.git-graph"
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

for extension in "${extensions[@]}"; do
    code --install-extension "$extension"
done

