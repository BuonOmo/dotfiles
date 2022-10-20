#!/usr/bin/env zsh

source $HOME/.zshrc
mkdir -p $ZSH_CUSTOM/plugins
while read -r repo; do
	git clone git@github.com:$repo.git $ZSH_CUSTOM/plugins/${repo:t}
done <<-REPOS
	BuonOmo/zsh-command-time
	zsh-users/zsh-completions
	zsh-users/zsh-autosuggestions
REPOS
