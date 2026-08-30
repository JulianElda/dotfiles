local ret_status="%{$fg[red]%}$"
PROMPT='$fg_bold[blue]アーチ %{$fg[green]%}%~%{$fg_bold[white]%}$(git_prompt_info)%{$fg_bold[blue]%} 
${ret_status} %{$reset_color%}'

ZSH_THEME_GIT_PROMPT_PREFIX=" ➤ %{$fg[yellow]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[white]%}"
