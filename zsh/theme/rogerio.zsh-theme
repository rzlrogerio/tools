# yellow-sea-diamonds.zsh-theme
# https://github.com/jimratliff/yellow-sea-diamonds-zsh-theme

# REPORT VIRTUAL ENVIRONMENT

function virtualenv_info {
    [ $VIRTUAL_ENV ] && echo '('`basename $VIRTUAL_ENV`')'
}

VIRTUALENV_REPORT=$FG[040]\$(virtualenv_info)%f

# REPORT CURRENT WORKING DIRECTORY (CWD)
# Explanation of: %0~
#   If the CWD starts with $HOME, that part is replaced by “~”. Furthermore, if it has a named directory as its prefix,
#   that part is replaced by “~” followed by the name of the directory, but only is the result is shorter than the full
#   path.

CWD_BASE="%0~"
CWD=$FG[226]$CWD_BASE%f

# date
#DATE_TIME="%D{%c}"
DATE_TIME="%D{%a, %d %b %Y %R}"

# hostname
HST_NAME="$fg[magenta] ${ret_status} %m%}"

#UPTIME=" - %F{cyan}$(uptime -p)%f"

function eks_context {
    echo "$(get-context.sh)"
}

function aws_account {
    echo "$(get-aws-account-fast.sh)"
}

function tf_workspace {
    if [[ -f .terraform/environment ]]; then
        local ws=$(< .terraform/environment)
        if [[ "$ws" == *prod* ]]; then
            echo "%F{red}⛅ tf:${ws}%f"
        else
            echo "%F{green}⛅ tf:${ws}%f"
        fi
    elif [[ -d .terraform ]]; then
        echo "%F{green}⛅ tf:default%f"
    fi
}

TUX="🐧%f "

# REPORT GIT BRANCH, STATUS, COMMIT, ETC>
# $(git_prompt_info) is a function built into Oh My Zsh which displays the current branch name.
# It also returns the following, which can be customized.

# Função para contar arquivos modificados no Git
function git_modified_count {
    local count=$(git status --porcelain 2>/dev/null | wc -l)
    [ $count -gt 0 ] && echo "$FG[202]($count files changed)%f"
}

# Prepended to the beginning of the git info
ZSH_THEME_GIT_PROMPT_PREFIX=" $FG[250]| git:%f $FG[135]"

# Conditionally returned if there are any uncommitted changes on your branch
# Returns a ❌ if there are uncommitted changes
ZSH_THEME_GIT_PROMPT_DIRTY="%{$FG[202]%} ✘%f"

# Conditionally returned if there are no uncommitted changes on your branch
# Returns a ✅ if the are no uncommitted changes on your branch
ZSH_THEME_GIT_PROMPT_CLEAN="%{$FG[040]%} ✔%f"

# Although ZSH_THEME_GIT_PROMPT_SUFFIX is often used as the vehicle for displaying the commit hash, I ran into
# a problem I wasn't able to solve when using ZSH_THEME_GIT_PROMPT_SUFFIX for that purpose: the commit hash
# wouldn't update automatically. (This typically has something to do with double quotes vs. single quotes, and
# the fix is using single quotes to delay evaluation.)
# However, by appending it to the prompt myself, I don't have that problem.
# The limitation that creates (as least as of the current state) is that I can't wrap the commit hash in
# delimiters, because those delimiters would display even when there is no commit hash.
# I need to set ZSH_THEME_GIT_PROMPT_SUFFIX to an empty string to prevent a default suffix from appearing.
ZSH_THEME_GIT_PROMPT_SUFFIX=""

# Atualizar o GIT_REPORT para incluir a contagem de arquivos modificados
GIT_REPORT="$FG[033]\$(git_prompt_info)%f \$(git_modified_count)"

# Appended to the end of git info
# Appends the hash of the commit
COMMIT_HASH='$FG[033]$(git_prompt_short_sha)%f'

# REPORT RETURN CODE
# The following expression:
#   %(?.$NOERROR.$ERROR_OCCURRED)
# is a ternary conditional, which shows the second argument ($NOERROR) if the condition is true, and show the third
# argument if the condition is false.
# The condition (%?) is the return code. (Zero is true in Zsh.)
# Displays $NOERROR if previous command exited normally
# Displays $ERROR_OCCURRED otherwise
# My personal preference: Display nothing if there was no error. A lack of error isn’t sufficiently informative to
# warrant the additional visual noise.
NOERROR=""
# NOERROR="✅"
# Displays "ERROR n" in White on Red background
ERROR_OCCURRED="$BG[001]$FG[255]ERROR #%?%f%k"

REPORT_RETURN_CODE="%(?.$NOERROR.$ERROR_OCCURRED)"

SML="¯\\_(ツ)_/¯"

function prompt_char {
    echo ' 🔶' && return
}

# NOW CONSTRUCT THE PROMPT
PROMPT="
╭─$VIRTUALENV_REPORT $CWD %{$DATE_TIME%} $GIT_REPORT $COMMIT_HASH %{$reset_color%} %{$SML%} \$(eks_context) \$(tf_workspace) %{$TUX%}
╰─$REPORT_RETURN_CODE\$(prompt_char) "
