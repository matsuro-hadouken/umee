#!/bin/bash

ACCOUNT_ADDRESS="umee1..."       # main umeed1
umeed_VAL_CONS_PUB=$(umeed tendermint show-validator) # umeed tendermint show-validator | jq .key
umeed_VAL_OPER="umeevaloper1..." # umeed keys show $ACCOUNT_ADDRESS --bech val -a
CHAIN_NAME="<ID>" # chain name

RPC='http://127.0.0.1:26657' # endpoint

page_json=1 # look in validators array on specific page. If we can't see on page 1 then we can check on page 2

red_bg="\e[36m"
red="\e[31m"
colorize="\e[0;91m"
blue="\e[1;34m"
reset="\e[0m"

echo && echo -e " ${colorize}${red_bg}STATUS${reset}" && echo

status_data=$(curl -s "$RPC"/status 2>&1)

current_height=$(echo "$status_data" | jq -r '.result.sync_info | .latest_block_height')
sync_status=$(echo "$status_data" | jq -r '.result.sync_info | .catching_up')
voting_power=$(echo "$status_data" | jq -r '.result.validator_info.voting_power')

validator_pub_key=$(echo "$status_data" | jq -r '.result.validator_info.pub_key.value')

# echo "======> $validator_pub_key" && exit

echo -e " ${blue}Current height:${reset} $current_height"
echo -e " ${blue}Voting power:${reset}   $voting_power"

echo && echo -e " ${colorize}${red_bg}SLASHING${reset}" && echo
umeed query slashing signing-info "$umeed_VAL_CONS_PUB" --chain-id "$CHAIN_NAME" --node "$RPC" -o json | jq

echo && echo -e " ${colorize}${red_bg}VALIDATORS ARRAY${reset}" && echo
umeed query tendermint-validator-set --page "$page_json" | jq --arg validator_pub_key "$validator_pub_key" '.validators | .[] | select(.pub_key.value == $validator_pub_key) | del(.pub_key)'

echo && echo -e " ${colorize}${red_bg}STAKING${reset}" && echo

staking_data=$(umeed query staking validator "$umeed_VAL_OPER" --node "$RPC" -o json)

jail_state=$(echo "$staking_data" | jq -r .jailed)
validator_status=$(echo "$staking_data" | jq -r .status)
tokens_bonded=$(echo "$staking_data" | jq -r .tokens)
operator_address=$(echo "$staking_data" | jq -r .operator_address)
operator_public_key=$(echo "$staking_data" | jq -r .consensus_pubkey.key)
unbonding_height=$(echo "$staking_data" | jq -r .unbonding_height)

uumeed_to_umeed=$(echo "scale=0; $tokens_bonded / 1000000" | bc -l)

echo -e " ${blue}Validator status:${reset}     $validator_status"
echo -e " ${blue}Bonded tokens:${reset}        $tokens_bonded  ${colorize}${red_bg}[ $uumeed_to_umeed umee ]${reset}"
echo -e " ${blue}Operator address:${reset}     $operator_address"
echo -e " ${blue}Consensus public key:${reset} $operator_public_key"
echo -e " ${blue}Unbonding height:${reset}     $unbonding_height"

echo && echo -e " ${colorize}${red_bg}BALANCE${reset}" && echo
validator_account_balance=$(umeed --node "$RPC" query bank balances "$ACCOUNT_ADDRESS" --chain-id "$CHAIN_NAME" -o json 2>&1 | jq -r '.balances | .[] | .amount')

echo -e " ${blue}Owner account balance:${reset} $validator_account_balance ${colorize}${red_bg}[ $ACCOUNT_ADDRESS ]${reset}" && echo

echo -e " ${blue}Out of sync:${reset} ${red} $sync_status${reset}"
echo -e " ${colorize}${blue}Jail state:${reset}${red}   $jail_state${reset}" && echo
