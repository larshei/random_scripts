#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# 1. Parse command line args
# -----------------------------
WORD_COUNT=4
SPECIAL_CHARS="~-_&%#!?=$+"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--num-words)
      WORD_COUNT="$2"
      shift 2
      ;;
    -s|--special-chars)
      SPECIAL_CHARS="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# -----------------------------
# 2. Detect OS and dictionaries
# -----------------------------
DICT_CANDIDATES=()

# Common Linux dictionary paths
for d in /usr/share/dict/* /usr/dict/*; do
  [[ -f "$d" ]] && DICT_CANDIDATES+=("$d")
done

if [[ ${#DICT_CANDIDATES[@]} -eq 0 ]]; then
  echo "No dictionary files found." >&2
  exit 1
fi

# -----------------------------
# 3. Let user choose dictionary
# -----------------------------
if [[ ${#DICT_CANDIDATES[@]} -gt 1 ]]; then
  echo "Available dictionaries:"
  for i in "${!DICT_CANDIDATES[@]}"; do
    printf "%2d) %s\n" "$((i+1))" "${DICT_CANDIDATES[$i]}"
  done

  read -p "Select dictionary (1-${#DICT_CANDIDATES[@]}): " IDX
  IDX=$((IDX-1))

  if [[ $IDX -lt 0 || $IDX -ge ${#DICT_CANDIDATES[@]} ]]; then
    echo "Invalid selection." >&2
    exit 1
  fi

  DICT="${DICT_CANDIDATES[$IDX]}"
else
  DICT="${DICT_CANDIDATES[0]}"
fi

# Load words and keep only alphabetic ones
WORDS=( $(grep -E '^[A-Za-z]+$' "$DICT") )

echo "Loaded ${#WORDS[@]} words from dictionary."

if [[ ${#WORDS[@]} -lt $WORD_COUNT ]]; then
  echo "Dictionary too small." >&2
  exit 1
fi

# -----------------------------
# Helper functions
# -----------------------------
random_word() {
local max=${#WORDS[@]}
  # get a 4-byte random integer
  local r=$(od -An -N4 -tu4 < /dev/urandom)
  local idx=$(( r % max ))
  local w="${WORDS[$idx]}"

  # randomly uppercase or lowercase
  if (( RANDOM % 2 )); then
    echo "$w" | tr '[:lower:]' '[:upper:]'
  else
    echo "$w" | tr '[:upper:]' '[:lower:]'
  fi
}

random_special() {
  local len=${#SPECIAL_CHARS}
  echo -n "${SPECIAL_CHARS:RANDOM%len:1}"
}

calc_entropy() {
  local num_words=$1
  local wordlist_size=$2
  local num_specials=$3

  # entropy = N*log2(|words|) + (N-1)*log2(|specials|)
  local e_words=$(awk -v n="$num_words" -v w="$wordlist_size" 'BEGIN { print n * log(w)/log(2) }')
  local e_sep=$(awk -v n="$num_words" -v s="$num_specials" 'BEGIN { print (n-1) * log(s)/log(2) }')
  awk -v a="$e_words" -v b="$e_sep" 'BEGIN { print a + b }'
}

# -----------------------------
# 4. Generate 4 passwords
# -----------------------------
echo

ENTROPY=$(calc_entropy "$WORD_COUNT" "${#WORDS[@]}" "${#SPECIAL_CHARS}")
printf "Estimated entropy: %.2f bits\n" "$ENTROPY"

echo "Generated passwords:"
for _ in {1..4}; do
  PW=""
  for ((i=1;i<=WORD_COUNT;i++)); do
    if [[ $i -gt 1 ]]; then
      PW+=$(random_special)
    fi
    PW+=$(random_word)
  done
  echo "$PW"
done
