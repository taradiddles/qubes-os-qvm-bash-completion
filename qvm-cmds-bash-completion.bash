# qvm-* commands bash auto completion

# Review this file first as you must copy it to dom0. Then:
#  - copy to /etc/bash_completion.d/
#  - or, `source` it from .bashrc

# idea from https://www.mail-archive.com/qubes-users@googlegroups.com/msg20088.html
#  credit to haaber for the original PoC !

# @taradiddles / initial version: apr 2018 / GPLv2
# jun 2023: code refactoring, shellcheck fixes, non-cryptic comments, etc.



# ---------------------------------------------------------------------------
# COMPLETION FUNCTIONS

# Output the relative position of COMP_CWORD with option words ignored
# Note: This logic is flawed when using option arguments (eg. -s blah).
#       Unfortunately there is no way to solve this except parsing every
#       known option for a given qvm-* command
_get-cword-pos() {
	local index=0
	local i
	for ((i=1; i<=COMP_CWORD; i++)); do 
		[[ ${COMP_WORDS[i]} == -* ]] && continue
		((index++))
	done
	echo ${index}
}

# Output the relative position of the first COMP_CWORD with option words ignored
# Note: Same limitation as _get-cword-pos() above.
_get-first-cword() {
	local i
	for ((i=1; i<=COMP_CWORD; i++)); do 
		[[ ${COMP_WORDS[i]} == -* ]] && continue
		echo "${COMP_WORDS[i]}"
		return 0
	done
	echo ""
}

# Sets COMPREPLY to an array of qubes in a given state
_complete-qubes() {
	local qubes
	local state="${1}"
	local state_re=''
	local cur="${COMP_WORDS[COMP_CWORD]}"
	case "${state}" in
		running|halted|paused)
			state_re="${state}"
			;;
		runtrans)
			state_re='\(running\|transient\)'
			;;
		any_state)
			state_re='[^|]\+'
			;;
	esac
	qubes=$(qvm-ls --raw-data | grep -v '^dom0|' | \
		grep -i "^[^|]\+|${state_re}|" | cut -f1 -d"|")
	mapfile -t COMPREPLY < <(compgen -W "${qubes}" -- "${cur}")
	return 0
}

# Filename completion
_complete-filenames() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	mapfile -t COMPREPLY < <(compgen -f -- "$cur")
	return 0
}

# qube prefs / features / tags / service completion
_complete-qubeprops() {
	local qube="${1}"
	local property="${2}"
	local props
	local cur="${COMP_WORDS[COMP_CWORD]}"
	if qvm-check "${qube}" > /dev/null 2>&1; then
		case "${property}" in
			prefs|features|tags|service)
				props=$("qvm-${property}" "${qube}" | \
					cut -f1 -d " ")
				;;
		esac
	fi
	mapfile -t COMPREPLY < <(compgen -W "${props}" -- "${cur}")
}


# ---------------------------------------------------------------------------
# qvm-* commands

# --------------
# each argument is completed, with qubes in any state
_qvmcmd-any_state-all_args() {
	_complete-qubes "any_state"
}
complete -F _qvmcmd-any_state-all_args qvm-backup
complete -F _qvmcmd-any_state-all_args qvm-ls


# --------------
# first argument completed, with qubes in a given state
_qvmcmd-in_state() {
	local state="$1"
	[ "$(_get-cword-pos "${COMP_CWORD}")" = 1 ] &&
		_complete-qubes "${state}"
}

_qvmcmd-any_state() { _qvmcmd-in_state "any_state"; }
complete -F _qvmcmd-any_state qvm-check
complete -F _qvmcmd-any_state qvm-clone
complete -F _qvmcmd-any_state qvm-firewall
complete -F _qvmcmd-any_state qvm-remove
complete -F _qvmcmd-any_state qvm-run
complete -F _qvmcmd-any_state qvm-service
complete -F _qvmcmd-any_state qvm-start-gui
complete -F _qvmcmd-any_state qvm-usb

_qvmcmd-halted() { _qvmcmd-in_state "halted"; }
complete -F _qvmcmd-halted qvm-start

_qvmcmd-paused() { _qvmcmd-in_state "paused"; }
complete -F _qvmcmd-paused qvm-unpause

_qvmcmd-running() { _qvmcmd-in_state "running"; }
complete -F _qvmcmd-running qvm-pause
complete -F _qvmcmd-running qvm-shutdown

_qvmcmd-runtrans() { _qvmcmd-in_state "runtrans"; }
complete -F _qvmcmd-runtrans qvm-kill


# --------------
# first argument completed, with qubes in any state
# n>=2 argument completed, with filenames
_qvmcmd-all-filenames() {
	if [ "$(_get-cword-pos "${COMP_CWORD}")" = 1 ]; then
		 _complete-qubes "any_state"
	else
		_complete-filenames
	fi
}
complete -F _qvmcmd-all-filenames qvm-copy-to-vm
complete -F _qvmcmd-all-filenames qvm-move-to-vm


# --------------
# first argument completed, with qubes in any state
# second argument completed, with qube property (service, prefs, features, ...)
_qvmcmd-all-qubeprop() {
	local property="$1"
	case "$(_get-cword-pos "${COMP_CWORD}")" in
		1)
			_complete-qubes "any_state"
			;;
		2)
			_complete-qubeprops "$(_get-first-cword)" "${property}"
			;;
	esac
}

_qvmcmd-all-qubeprefs() { _qvmcmd-all-qubeprop "prefs"; }
complete -F _qvmcmd-all-qubeprefs qvm-prefs

_qvmcmd-all-qubefeatures() { _qvmcmd-all-qubeprop "features"; }
complete -F _qvmcmd-all-qubefeatures qvm-features

_qvmcmd-all-qubetags() { _qvmcmd-all-qubeprop "tags"; }
complete -F _qvmcmd-all-qubetags qvm-tags

_qvmcmd-all-qubeservice() { _qvmcmd-all-qubeprop "service"; }
complete -F _qvmcmd-all-qubeservice qvm-service

