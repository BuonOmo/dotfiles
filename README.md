# Dotfiles

Install with:

```zsh
zsh -c "$(curl -fsSL https://raw.githubusercontent.com/BuonOmo/dotfiles/main/install.zsh)"
```

Update with:

```zsh
dotf pull
```

Contribute with:

```zsh
dotf add .somerc
dotf commit
# fork if needed
dotf push
# PR welcome
```

## Configuration

Configuration is made by running the script with some env variables set.

*`WITCHCRAFT_SCRIPT_PATH`* sets the path where your [witchcraft scripts](https://luciopaiva.com/witchcraft)
are gonna be stored. If not set, the default will be `$HOME/Dev/BuonOmo/chrome-script` and the
[corresponding repo](https://github.com/BuonOmo/chrome-scripts) will be downloaded accordingly.

