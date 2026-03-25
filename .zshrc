# Git-aware prompt
autoload -Uz add-zsh-hook

function _git_prompt_info() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || \
    branch=$(git rev-parse --short HEAD 2>/dev/null) || return

    local git_status="" color="%F{green}"
    local staged=0 unstaged=0 untracked=0

    # Parse git status --porcelain once
    local line
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local idx="${line[1]}" wt="${line[2]}"
        [[ "$idx" == "?" ]] && (( untracked++ )) && continue
        [[ "$idx" != " " && "$idx" != "?" ]] && (( staged++ ))
        [[ "$wt" != " " && "$wt" != "?" ]] && (( unstaged++ ))
    done < <(git status --porcelain 2>/dev/null)

    # Build status indicators
    (( staged > 0 ))    && git_status+="%F{green}+${staged}"
    (( unstaged > 0 ))  && git_status+="%F{red}~${unstaged}"
    (( untracked > 0 )) && git_status+="%F{blue}?${untracked}"

    # Branch color: green=clean, yellow=dirty
    if (( staged + unstaged + untracked > 0 )); then
        color="%F{yellow}"
    fi

    # Ahead/behind upstream
    local ab
    ab=$(git rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
    if [[ -n "$ab" ]]; then
        local ahead="${ab%%$'\t'*}" behind="${ab##*$'\t'}"
        (( ahead > 0 ))  && git_status+="%F{cyan}↑${ahead}"
        (( behind > 0 )) && git_status+="%F{magenta}↓${behind}"
    fi

    [[ -n "$git_status" ]] && git_status=" ${git_status}"

    echo " ${color}${branch}%f${git_status}%f"
}

setopt PROMPT_SUBST
PROMPT='%n %F{blue}%1~%f$(_git_prompt_info) %# '
eval "$(rbenv init -)"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias rm='rm -i'

alias gl='git log --graph --pretty=format:"%x09%C(green)%h%C(reset)%x09%C(yellow)%ar%C(reset) %x09%s%C(cyan)%d%C(reset) %C(blue)%an%C(reset)"'
alias gla='gl --all'
alias gfu='git fetch upstream && git pull upstream master'
alias gst='git status'
alias gb='git branch'
alias gcm='git checkout master'
alias gbs='git for-each-ref --sort=committerdate refs/heads/ | sed "s-.*commit.refs/heads/--"'

function git_push_origin {
    git push $* origin `git rev-parse --abbrev-ref HEAD`
}

alias gpo=git_push_origin
alias be='bundle exec'
