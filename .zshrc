# ((USE_ZPROF = 1)) # Uncomment to use :)
((USE_ZPROF == 1)) && zmodload zsh/zprof # Must always be at the beginning!

# Some things to read to be the best zsh-er:
# - https://zsh.sourceforge.io/Guide/zshguide05.html

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh
export ZSH_CUSTOM=$HOME/.zsh/custom

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="crunchrobby" # https://ulysse.md/2021/07/18/Unexpected-long-running-command.html

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

HIST_STAMPS="yyyy-mm-dd" # "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd" or 'man strftime'

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	git
	rust
	zsh-command-time
	zsh-completions
	zsh-autosuggestions
)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC=letsgobb

source $ZSH/oh-my-zsh.sh

PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
PATH="$ZSH_CUSTOM/bin:$PATH"

source $ZSH_CUSTOM/aliases

type brew &>/dev/null && fpath=( "$(brew --prefix)/share/zsh/site-functions" $fpath )

# Ruby stuff

export RUBYOPT="-r$HOME/.ruby/debug.rb"

export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"

# Lazy load ruby/rbenv related stuff (see npm below for a more canonical example).
if [[ -d "$HOME/.rbenv" ]]; then
	shims=($HOME/.rbenv/shims/* rbenv)
	shims=(${shims:t})
	for shim in $shims; do
		"$shim"() {
			unfunction "$0"
			[[ "$RBENV_SHELL" == "zsh" ]] || eval "$(rbenv init -)"
			"$0" "$@"
		}
	done
	unset shims
fi

# Autoload functions
# https://dev.to/voyeg3r/some-pearls-from-my-zshrc-282m
MY_ZSH_FPATH=$ZSH_CUSTOM/functions
fpath=( $MY_ZSH_FPATH $fpath )

if [[ -d "$MY_ZSH_FPATH" ]]; then
    for func in $MY_ZSH_FPATH/*; do
        autoload -Uz ${func:t:r} # t removes the directory, r the suffix.
    done
fi
unset MY_ZSH_FPATH

# NOTE: this has to be done after $fpath is complete to be sure we don't leave
#   any completion function.
autoload -Uz compinit && compinit

# Avoid loading node related stuff when not used (saves 0.5s at boot!)
# Goodness from (and many other at) https://dev.to/voyeg3r/some-pearls-from-my-zshrc-282m
__load_node() {
    unfunction nvm node npm
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
}

nvm()  { __load_node; nvm  "$@" }
node() { __load_node; node "$@" }
npm()  { __load_node; npm  "$@" }

# Same for emscripten
emcc() {
	unfunction emcc
	source "/some/path/to/emsdk/emsdk_env.sh"
	emcc "$@"
}

# And autojump
j() {
	unfunction j
	# 'brew info autojump' if the next line fails.
	[ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
	j "$@"
}

alias timezsh='for i in $(seq 1 10); do time zsh -lic exit; done'
((USE_ZPROF == 1)) && zprof || true # Must always be at the end!