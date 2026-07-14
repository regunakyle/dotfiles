$extensions = @(
    "alefragnani.project-manager"
    "ibm.output-colorizer"
    "mikestead.dotenv"
    "ms-toolsai.jupyter-keymap"
    "ms-vscode-remote.remote-containers"
    "ms-vscode-remote.remote-ssh"
    "ms-vscode-remote.remote-wsl"
    "tomoki1207.pdf"
    "usernamehw.errorlens"
    "vincaslt.highlight-matching-tag"
    "vscode-icons-team.vscode-icons"
    "yoavbls.pretty-ts-errors"
)

foreach ($extension in $extensions) {
    code --install-extension $extension
}
