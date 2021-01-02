# GIT
GIT_UNCOMMITTED="${GIT_UNCOMMITTED:-+}"
GIT_UNSTAGED="${GIT_UNSTAGED:-!}"
GIT_UNTRACKED="${GIT_UNTRACKED:-?}"
GIT_STASHED="${GIT_STASHED:-$}"
GIT_UNPULLED="${GIT_UNPULLED:-⇣}"
GIT_UNPUSHED="${GIT_UNPUSHED:-⇡}"

# YARN
YARN_ENABLED=false
TOUCHBAR_GIT_ENABLED=true

# https://unix.stackexchange.com/a/22215
find-up () {
  path=$PWD
  while [[ "$path" != "" && ! -e "$path/$1" ]]; do
    path=${path%/*}
  done
  echo "$path"
}

pecho() {
  if [ -n "$TMUX" ]; then
    echo -ne "\ePtmux;\e$*\e\\"
  else
    echo -ne $*
  fi
}

# F1-12: https://github.com/vmalloc/zsh-config/blob/master/extras/function_keys.zsh
# F13-F20: just running read and pressing F13 through F20. F21-24 don't print escape sequences
fnKeys=('^[OP' '^[OQ' '^[OR' '^[OS' '^[[15~' '^[[17~' '^[[18~' '^[[19~' '^[[20~' '^[[21~' '^[[23~' '^[[24~' '^[[1;2P' '^[[1;2Q' '^[[1;2R' '^[[1;2S' '^[[15;2~' '^[[17;2~' '^[[18;2~' '^[[19;2~')
touchBarState=''
npmScripts=()
gitBranches=()
lastPackageJsonPath=''
lastMakefilePath=''

function _clearTouchbar() {
  pecho "\033]1337;PopKeyLabels\a"
}

function _unbindTouchbar() {
  for fnKey in "$fnKeys[@]"; do
    bindkey -s "$fnKey" ''
  done
}

function setKey(){
  pecho "\033]1337;SetKeyLabel=F${1}=${2}\a"
  if [ "$4" != "-q" ]; then
    bindkey -s $fnKeys[$1] "$3 \n"
  else
    bindkey $fnKeys[$1] $3
  fi
}

function clearKey(){
  pecho "\033]1337;SetKeyLabel=F${1}=F${1}\a"
}

function _displayDefault() {
  if [[ $touchBarState != "" ]]; then
    _clearTouchbar
  fi
  _unbindTouchbar
  touchBarState=""

  # CURRENT_DIR
  # -----------
  setKey 1 "👉 $(echo $PWD | awk -F/ '{print $(NF-1)"/"$(NF)}')" _displayPath '-q'

  # GIT
  # ---
  # Check if the current directory is a git repository and not the .git directory
  if [[ "$TOUCHBAR_GIT_ENABLED" = true ]] &&
    git rev-parse --is-inside-work-tree &>/dev/null &&
    [[ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]]; then

    # Ensure the index is up to date.
    git update-index --really-refresh -q &>/dev/null

    # String of indicators
    local indicators=''

    indicators+="$(git_uncomitted)"
    indicators+="$(git_unstaged)"
    indicators+="$(git_untracked)"
    indicators+="$(git_stashed)"
    indicators+="$(git_unpushed_unpulled)"

    [ -n "${indicators}" ] && touchbarIndicators="🔥[${indicators}]" || touchbarIndicators="🙌";

    #setKey 2 "🎋 `git_current_branch`" _displayBranches '-q'
    #setKey 3 $touchbarIndicators "git status"
    #setKey 4 "🔼 push" "git push origin $(git_current_branch)"
    #setKey 5 "🔽 pull" "git pull origin $(git_current_branch)"
  else
    true
    #clearKey 2
    #clearKey 3
    #clearKey 4
    #clearKey 5
  fi

  # PACKAGE.JSON
  # ------------
  if [[ $(find-up package.json) != "" ]]; then
      if [[ $(find-up yarn.lock) != "" ]] && [[ "$YARN_ENABLED" = true ]]; then
          setKey 2 "🐱 yarn-run" _displayYarnScripts '-q'
      else
          setKey 2 "⚡️ npm-run" _displayNpmScripts '-q'
    fi
  else
      clearKey 3
  fi
}

function _displayNpmScripts() {
  # find available npm run scripts only if new directory
  if [[ $lastPackageJsonPath != $(find-up package.json) ]]; then
    lastPackageJsonPath=$(find-up package.json)
    if [[ -e "$lastPackageJsonPath/package.json" ]]; then
      npmScripts=($(jq -j '.scripts | keys[] | "\(.) "' "$lastPackageJsonPath/package.json"))
    else
      npmScripts=()
    fi
  fi

  _clearTouchbar
  _unbindTouchbar

  touchBarState='npm'

  fnKeysIndex=0
  for npmScript in "$npmScripts[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    setKey $fnKeysIndex $npmScript "npm run $npmScript"
  done

  #setKey 1 "👈 back" _displayDefault '-q'
}

function _displayMakeTargets() {
  # find available make targets only if new directory
  if [[ $lastMakefilePath != "$PWD" ]]; then
    lastMakefilePath=$PWD
    # Adapted from:
    # https://unix.stackexchange.com/questions/230047/how-to-list-all-targets-in-make/230050#230050
    # Unsure why "Makefile" is included in here... but it is excluded in the
    # below awk script.
    if [[ -e "$PWD/Makefile" ]]; then
      makeTargets=($(make -qp | awk -F':' '/^[a-zA-Z0-9][^$#\/\t=]*:([^=]|$)/ {split($1,A,/ /);for(i in A) { if (A[i] != "Makefile") printf "%s ", A[i] } }'))
    else
      makeTargets=()
    fi
  fi

  _clearTouchbar
  _unbindTouchbar

  touchBarState='make'

  if [[ ${#makeTargets[@]} -gt 0 ]]; then
    fnKeysIndex=0
    for target in "$makeTargets[@]"; do
      fnKeysIndex=$((fnKeysIndex + 1))
      setKey $fnKeysIndex $target "make $target"
    done
  fi
}

function _displayYarnScripts() {
  # find available yarn run scripts only if new directory
  if [[ $lastPackageJsonPath != $(find-up package.json) ]]; then
    lastPackageJsonPath=$(find-up package.json)
    yarnScripts=($(node -e "console.log([$(yarn run --json 2>>/dev/null | tr '\n' ',')].find(line => line && line.type === 'list' && line.data && line.data.type === 'possibleCommands').data.items.sort((a, b) => a.localeCompare(b)).filter((name, idx) => idx < 19).join(' '))"))
  fi

  _clearTouchbar
  _unbindTouchbar

  touchBarState='yarn'

  fnKeysIndex=1
  for yarnScript in "$yarnScripts[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    setKey $fnKeysIndex $yarnScript "yarn run $yarnScript"
  done

  setKey 1 "👈 back" _displayDefault '-q'
}

function _displayBranches() {
  # List of branches for current repo
  gitBranches=($(node -e "console.log('$(echo $(git branch))'.split(/[ ,]+/).toString().split(',').join(' ').toString().replace('* ', ''))"))

  _clearTouchbar
  _unbindTouchbar

  # change to github state
  touchBarState='github'

  fnKeysIndex=1
  # for each branch name, bind it to a key
  for branch in "$gitBranches[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    setKey $fnKeysIndex $branch "git checkout $branch"
  done

  setKey 1 "👈 back" _displayDefault '-q'
}

#function _displayPath() {
#  _clearTouchbar
#  _unbindTouchbar
#  touchBarState='path'
#
#  IFS="/" read -rA directories <<< "$PWD"
#  fnKeysIndex=2
#  for dir in "${directories[@]:1}"; do
#    setKey $fnKeysIndex "$dir" "cd $(pwd | cut -d'/' -f-$fnKeysIndex)"
#    fnKeysIndex=$((fnKeysIndex + 1))
#  done
#
#  setKey 1 "👈 back" _displayDefault '-q'
#}

#zle -N _displayDefault
zle -N _displayNpmScripts
zle -N _displayMakeTargets
#zle -N _displayYarnScripts
#zle -N _displayBranches
#zle -N _displayPath

precmd_iterm_touchbar() {
  if [[ -e "$PWD/Makefile" ]]; then
    _displayMakeTargets
  else
    _displayNpmScripts
  fi
  #if [[ $touchBarState == 'npm' ]]; then
  #  _displayNpmScripts
  #elif [[ $touchBarState == 'yarn' ]]; then
  #  _displayYarnScripts
  #elif [[ $touchBarState == 'github' ]]; then
  #  _displayBranches
  #elif [[ $touchBarState == 'path' ]]; then
  #  _displayPath
  #else
  #  _displayDefault
  #fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd precmd_iterm_touchbar
