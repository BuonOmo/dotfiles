# TODO: eventually use %!
CRUNCH_BRACKET_COLOR="%{$fg[white]%}"
CRUNCH_TIME_COLOR="%(?:%{$fg[yellow]%}:%{$fg[red]%})"
CRUNCH_TIME_="${CRUNCH_TIME_COLOR}%T%{$reset_color%}"
#CRUNCH_TIME_="$CRUNCH_BRACKET_COLOR{$CRUNCH_TIME_COLOR%T$CRUNCH_BRACKET_COLOR}%{$reset_color%}"

PROMPT=$'\n'"$CRUNCH_TIME_ "
PROMPT+=' %{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}git:(%{$fg[red]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%})"
