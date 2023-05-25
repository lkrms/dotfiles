#!/bin/bash

[[ ! -f ~/.config/openssl.cnf ]] ||
    export OPENSSL_CONF=~/.config/openssl.cnf
