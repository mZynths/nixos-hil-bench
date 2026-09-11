# ------------------------------------------------------------------------------
# Zynths Theme (Catppuccin Mocha Edition)
# Mac/Linux/Conda/ASCII Friendly
# ------------------------------------------------------------------------------

# --- Official Catppuccin Mocha Palette ---
# Reference: https://github.com/catppuccin/catppuccin
# NOTE: must NOT be local — PROMPT is single-quoted and re-evaluated at render
# time, so these variables must persist beyond the file's load scope.
CTp_BLUE="#89b4fa"      # User
CTp_GREEN="#a6e3a1"     # Conda Env
CTp_PINK="#f5c2e7"      # Path
CTp_LAVENDER="#b4befe"  # Git
CTp_TEXT="#cdd6f4"      # Main text
CTp_OVERLAY="#9399b2"   # Closer/Arrow (Subtle Grey)

p_SILVERY="#d3d6e0"

# --- Millisecond timestamp (NixOS ships GNU coreutils; %N is native) ---
function _ms_now() {
    echo $(( $(date +%s%N) / 1000000 ))
}

# --- Functions ---

# 1. Conda Environment Segment
function prompt_conda_python_env() {
    if [[ -n $CONDA_DEFAULT_ENV ]]; then
        echo "%F{$CTp_GREEN}(${CONDA_DEFAULT_ENV}) %f"
    fi
}

# 2. Git Settings
ZSH_THEME_GIT_PROMPT_PREFIX="%F{$CTp_LAVENDER}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f "
ZSH_THEME_GIT_PROMPT_DIRTY="%F{$CTp_LAVENDER}*%f"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# --- Prompt Construction ---

# PROMPT Structure:
# 1. Conda env  (Green - hidden if no env active)
# 2. User       (Blue)
# 3. @host      (Silvery)
# 4. Path       (Pink, last 2 components)
# 5. Git        (Lavender)
# 6. Closer     (Overlay Grey >)

PROMPT='%f$(prompt_conda_python_env)%F{$CTp_BLUE}%n%F{$CTp_OVERLAY}@%F{$p_SILVERY}%m %F{$CTp_PINK}%2~ %f$(git_prompt_info)%F{$CTp_OVERLAY}>%f '

# --- Elapsed time (right prompt) ---

function preexec() {
    _cmd_start=$(_ms_now)
}

function precmd() {
    if [[ -n $_cmd_start ]]; then
        local now=$(_ms_now)
        local elapsed=$(( now - _cmd_start ))
        export RPROMPT="%F{$CTp_GREEN}${elapsed}ms %{$reset_color%}"
        unset _cmd_start
    else
        export RPROMPT=""
    fi
}
