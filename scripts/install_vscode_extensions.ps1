$extensions = @(
    "alefragnani.project-manager"
    "esbenp.prettier-vscode"
    "eamodio.gitlens"
    "ibm.output-colorizer"
    "mechatroner.rainbow-csv"
    "medo64.render-crlf"
    "Mescius.spreadjs-xlsx-editor"
    "mhutchie.git-graph"
    "mikestead.dotenv"
    "ms-toolsai.jupyter-keymap"
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
)

foreach ($extension in $extensions) {
    code --install-extension $extension
}
