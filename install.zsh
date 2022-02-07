set -e

die() {
	>&2 echo $1
	exit 1
}

[[ -n "$ZSH_VERSION" ]] || die 'Please use zsh'

[[ -d "$HOME/.oh-my-zsh" ]] || sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
type brew > /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew bundle # See ~/Brewfile

function dotfiles {
   /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $@
}

	git clone --bare git@github.com:BuonOmo/dotfiles.git $HOME/.dotfiles
	mkdir -p .dotfiles.old
	dotfiles checkout

	if [[ $? != 0 ]]; then
		dotfiles checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .dotfiles.old/{}
	fi;

	dotfiles checkout
	dotfiles config status.showUntrackedFiles no

   for unwanted in $HOME/install.zsh $HOME/README.md $HOME/LICENSE; do
      rm $unwanted
      dotfiles update-index --assume-unchanged $unwanted
   done

unfunction dotfiles
