#!/bin/bash
set -e


printf "\n\nRunning SH test...\n"
./sh.sh

printf "\n\nRunning BASH test...\n"
./bash.sh

printf "\n\nRunning ZSH test...\n"
./zsh.sh

printf "\n\nRunning KSH test...\n"
./ksh.sh

printf "\n\n=================================\n"
printf "Tests complete\n"
