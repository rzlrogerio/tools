#!/bin/bash - 
#===============================================================================
#
#          FILE: valida-cert.sh
# 
#         USAGE: ./valida-cert.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 07/22/2026 04:42
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Dominio
DOM="$1"
echo | openssl s_client -connect $DOM:443 > /tmp/$DOM
openssl x509 -noout -in /tmp/$DOM -issuer -subject -dates
