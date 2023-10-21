exec 3>&1
exec 1>&2

move_cursor() {
  printf "\x1b[$(( 10 + $1 ));21f"
}

readinput() {
	read -rsn1 mode

	case $mode in
		'') read -rsn2 mode ;;
		'') echo kB ;;
		'') echo kE ;;
		*) echo $mode ;;
	esac

	case $mode in
		'[A') echo kU ;;
		'[B') echo kD ;;
		'[D') echo kL ;;
		'[C') echo kR ;;
	esac
}

selectorLoop() {
  maxopts=$1
  shift
  selected=0
  args=( "$@" )
  while true; do
    clear
    source assets/ui/menu
    idx=0
    lowerbound=$((selected - $maxopts))
    upperbound=$((selected + $maxopts))
    if [ $lowerbound -lt 0 ]; then upperbound=$(($upperbound + ${lowerbound#-})); lowerbound=0; fi
    if [ $upperbound -gt $# ]; then upperbound=$#; fi
    for i in $(seq $lowerbound $((upperbound - 1))); do
      move_cursor $idx
      arg=$(echo ${args[i]} | sed 's/\(.\{49\}\).*/\1.../')
      if [ $i -eq $selected ]; then
        echo -n "--> $arg"
      else
        echo -n "    $arg"
      fi
      idx=$((idx+1))
    done
    if [ $(($upperbound - $lowerbound)) -lt $(($maxopts + $maxopts)) ]; then
      if [ $(($maxopts + $maxopts)) -ne $# ]; then
        for i in $(seq 0 $(($maxopts + $maxopts + $lowerbound - $upperbound - 1))); do
          move_cursor $idx
          echo -n ""
          idx=$((idx+1))
        done
      fi
    fi
    idx=$((idx+1))
    move_cursor $idx
    echo -n "${lowerbound}-${upperbound} of $# items"
    printf "\x1b[33;0f"
    input=$(readinput)
    case $input in
      'kB') printf 'exit' >&3;exit ;;
      'kE') 
        if [ $# -eq 0 ]; then printf 'exit' >&3;exit; else printf $selected >&3;exit; fi;
        ;;
      'kU')
        ((selected--))
        if [ $selected -lt 0 ]; then selected=0; fi
        ;;
      'kD')
        ((selected++))
        if [ $selected -ge $# ]; then selected=$(($# - 1)); fi
        ;;
    esac
  done
}
selectorLoop 7 $@
