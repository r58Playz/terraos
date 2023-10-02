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
  selected=0
  while true; do
    idx=0
    for opt; do
      # TODO: move cursor
      if [ $idx -eq $selected ]; then
        echo -n "--> $(mapname $opt)"
      else
        echo -n "    $(mapname $opt)"
      fi
      ((idx++))
    done
    input=$(readinput)
    case $input in
      'kB') exit ;;
      'kE') return $selected ;;
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


selectorLoop $@
