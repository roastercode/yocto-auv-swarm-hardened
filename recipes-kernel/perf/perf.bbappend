# Piles d'appels resolues pour du C/C++ : deroulement DWARF, demangling
# et addr2line par LLVM, sondes SDT.
#
# Absents faute de fournisseur en wrynose :
#   babeltrace  perf ne gere que babeltrace v1, wrynose ne fournit que
#               babeltrace2 ; pas d'export CTF (perf data convert)
#   coresight   requiert opencsd, absent des couches de ce build
PACKAGECONFIG:append = " dwarf llvm systemtap"
