$extensions = @(
    "alefragnani.project-manager"
    "charliermarsh.ruff"
    "DavidAnson.vscode-markdownlint"
    "esbenp.prettier-vscode"
    "ggml-org.llama-vscode"
    "ibm.output-colorizer"
    "mechatroner.rainbow-csv"
    "medo64.render-crlf"
    "Mescius.spreadjs-xlsx-editor"
    "mhutchie.git-graph"
    "mikestead.dotenv"
    "ms-python.python"
    "ms-toolsai.datawrangler"
    "ms-toolsai.jupyter"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-wsl"
    "redhat.vscode-xml"
    "redhat.vscode-yaml"
    "ryu1kn.partial-diff"
    "streetsidesoftware.code-spell-checker"
    "tamasfe.even-better-toml"
    "tomoki1207.pdf"
    "usernamehw.errorlens"
    "vincaslt.highlight-matching-tag"
    "vscode-icons-team.vscode-icons"
    "yoavbls.pretty-ts-errors"
    "yzhang.markdown-all-in-one"
)

foreach ($extension in $extensions) {
    code --install-extension $extension
}
