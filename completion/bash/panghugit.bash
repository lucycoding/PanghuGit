# PanghuGit CLI bash completion
#
# 安装：
#   cp completion/bash/panghugit.bash /etc/bash_completion.d/panghugit
#   # 或通过 scripts/install_panghugit.sh --completion
#   # 然后 source /etc/bash_completion.d/panghugit 或重开终端

_panghugit_commands="version help which branch tag status-lines log diff show open"
_panghugit_actions="commit sync log diff switch init clone ignore stash merge rebase revert settings openWelcome branch tag blame submodule reposettings"
_panghugit_flags_global="--version -v --help -h"

_panghugit() {
  local cur prev words cword
  _init_completion || return

  local cmd=""
  local i
  for (( i = 1; i < cword; i++ )); do
    if [[ "${words[i]}" != -* ]]; then
      cmd="${words[i]}"
      break
    fi
  done

  if [[ -z "$cmd" ]]; then
    # 补全命令
    COMPREPLY=( $(compgen -W "$_panghugit_commands $_panghugit_flags_global" -- "$cur") )
    return
  fi

  case "$cmd" in
    open)
      if [[ "$prev" == "open" ]]; then
        COMPREPLY=( $(compgen -W "$_panghugit_actions" -- "$cur") )
        return
      fi
      # 之后补路径
      COMPREPLY=( $(compgen -d -- "$cur") )
      ;;
    log)
      case "$prev" in
        --author|--branch|--since|-n|--max-count)
          return
          ;;
        --oneline)
          return
          ;;
        *)
          if [[ "$cur" == --* ]]; then
            COMPREPLY=( $(compgen -W "--author --branch --since -n --max-count --oneline --graph" -- "$cur") )
          else
            COMPREPLY=( $(compgen -d -- "$cur") )
          fi
          ;;
      esac
      ;;
    diff)
      if [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--staged --cached --HEAD" -- "$cur") )
      else
        COMPREPLY=( $(compgen -d -- "$cur") )
      fi
      ;;
    show)
      if [[ "$prev" == "show" ]]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
      elif [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--stat --patch" -- "$cur") )
      fi
      ;;
    which|branch|tag|status-lines)
      COMPREPLY=( $(compgen -d -- "$cur") )
      ;;
    *)
      # action 简写
      if [[ " $_panghugit_actions " == *" $cmd "* ]]; then
        COMPREPLY=( $(compgen -d -- "$cur") )
      else
        COMPREPLY=( $(compgen -d -- "$cur") )
      fi
      ;;
  esac
}

complete -F _panghugit panghugit