set -xe

die() {
	>&2 echo $1
	exit 1
}

[[ -n "$ZSH_VERSION" ]] || die 'Please use zsh'

[[ -d "$HOME/.oh-my-zsh" ]] || {
	echo "⚠️ Installing Oh my ZSH, you’ll have to exit it to continue the installation process"
	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}
type brew > /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

function dotfiles {
   /usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $@
}

	git clone --bare git@github.com:BuonOmo/dotfiles.git $HOME/.dotfiles ||
		die "⚠️ Please setup github with ssh and try again. https://docs.github.com/en/authentication/connecting-to-github-with-ssh"

	# Backing up
	mkdir -p $HOME/.dotfiles.old
	for new_file in $(dotfiles ls-tree --full-tree -r --name-only HEAD); do
		[[ -f "$HOME/$new_file" ]] || continue

		echo "Backing up `~/$new_file` to `~/.dotfiles.old/$new_file`."
		mv "$new_file" ".dotfiles.old/$new_file"
	done
	[[ -z "$(ls -A $HOME/.dotfiles.old)" ]] && rm -d $HOME/.dotfiles.old

	dotfiles checkout
	dotfiles config status.showUntrackedFiles no

	for sub_installation_script in $HOME/install/*; do
		zsh $sub_installation_script
	done

   for unwanted in $HOME/install.zsh $HOME/install/* $HOME/README.md $HOME/LICENSE; do
      rm $unwanted
      dotfiles update-index --assume-unchanged $unwanted
   done

unfunction dotfiles

brew bundle # See ~/Brewfile
