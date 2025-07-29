#!/bin/bash

extensions=(
    "alefragnani.project-manager"
    "bierner.markdown-mermaid"
    "continue.continue"
    "DavidAnson.vscode-markdownlint"
    "eamodio.gitlens"
    "esbenp.prettier-vscode"
    "foxundermoon.shell-format"
    "github.vscode-github-actions"
    "GrapeCity.gc-excelviewer"
    "Gruntfuggly.todo-tree"
    "IBM.output-colorizer"
    "james-yu.latex-workshop"
    "mechatroner.rainbow-csv"
    "medo64.render-crlf"
    "mhutchie.git-graph"
    "mikestead.dotenv"
    "ms-azuretools.vscode-containers"
    "ms-kubernetes-tools.vscode-kubernetes-tools"
    "ms-playwright.playwright"
    "ms-vscode.live-server"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "redhat.ansible"
    "redhat.vscode-xml"
    "redhat.vscode-yaml"
    "ryu1kn.partial-diff"
    "streetsidesoftware.code-spell-checker"
    "tamasfe.even-better-toml"
    "tht13.rst-vscode" # Requires python3-docutils
    "timonwong.shellcheck"
    "tomoki1207.pdf"
    "usernamehw.errorlens"
    "vincaslt.highlight-matching-tag"
    "vscode-icons-team.vscode-icons"
    "yzhang.markdown-all-in-one"
)

extensions_extra=(
    "bradlc.vscode-tailwindcss"
    "charliermarsh.ruff"
    "dbaeumer.vscode-eslint"
    "expo.vscode-expo-tools"
    "josevseb.google-java-format-for-vs-code"
    "ms-python.python"
    "ms-toolsai.jupyter"
    "mylesmurphy.prettify-ts"
    "orta.vscode-jest"
    "shengchen.vscode-checkstyle"
    "VisualStudioExptTeam.vscodeintellicode"
    "vitest.explorer"
    "vmware.vscode-boot-dev-pack"
    "vscjava.vscode-java-pack"
    "YoavBls.pretty-ts-errors"
)

for extension in "${extensions[@]}"; do
    code --install-extension "$extension"
done

if [ $# -eq 0 ]; then
    for extension in "${extensions_extra[@]}"; do
        code --install-extension "$extension"
    done
fi
