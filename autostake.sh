#!/bin/bash

# speed staker for 'testnet', should 'not' be used in production blindly
# goal is to stake as fast as possible without abusing RPC ( assume we run script on the same machine )
# tendermint is weak as glass, every query practically meter and using automation in "production" should be controlled with extra precision
# we will use "test" key ring here, key will be exposed and available without password !

export PATH=/home/umee/.umee/cosmovisor/current/bin:$PATH

log_path="/home/<user>/autostake/delegations.log" # log path

valoper="umeevaloper1..."     # val operator
key_name="<key_name>"         # owner

min_delegate="500000"         # minimum to delegate
keep_for_comission="1000000"  # always keep on balance
reward_threshold="1000000"    # when withdraw reward
comission_threshold="1000000" # when withdraw comission

balance_treshold=$((min_delegate + keep_for_comission))

gas_price="0.00001uumee" # gas prices
gas_mult="1.20"          # multiplier

gas_schemea="--gas=auto --gas-prices $gas_price --gas-adjustment $gas_mult"

broadcast_method="async"

UMEE_VAL_CONS_PUB=$(umeed tendermint show-validator) # val cons pub

denom="uumee"

RPC='http://127.0.0.1:26657'
CHAIN="<chain_id>"

# sleeps
main_loop_interval="8"               # main loop interval ( we don't wan't this loop here, should trigger all sequence every time, without additional wait )
sequence_change="6"                  # if sequence missmatch, how long to wait before fix

wait_for_reward="6"                  # wait for reward hit input balance
balance_increase_check_comission="6" # wait after balance encreased before check transaction ( need to only wait once theoretically, otherwise we get slow )
wait_for_reward_in_loop="3"          # in case we fall in to chech loop, waiting for reward hit input

waiting_for_delegation="8"           # wait for delegation before starting check loop ( we don't want to wait inside loop )
delegation_loop_wait="3"             # wait in delegation loop, waiting for delegation to succeed

# -------------------------------------------------------------------------------------

numba="^[0-9]+([.][0-9]+)?$"

function get_address() {
    address=$(umeed keys list --keyring-backend test --output json | jq -Mrc --arg key_name "$key_name" '.[] |  select(.name == $key_name) | .address')
} # can be just set manualy

function get_current_balance() {
    balance_current=$(umeed q bank balances "$address" --node "$RPC" --chain-id "$CHAIN" --output json | jq -Mrc --arg denom "$denom" '.balances | .[] | select(.denom == $denom) | .amount')
    echo " $(date --utc +%FT%T.%3NZ) Current balance: $balance_current" >>"$log_path"
}

function get_current_reward() {
    reward_current=$(umeed query distribution rewards "$address" --output json | jq -Mrc '.total[] | .amount')
    reward_current=${reward_current%.*}
    echo " $(date --utc +%FT%T.%3NZ) Current reward: $reward_current" >>"$log_path"
}

function get_current_comission() {
    comission_current=$(umeed query distribution commission "$valoper" --output json | jq -Mrc '.commission[] | .amount' | tail -n1)
    comission_current=${comission_current%.*}
    echo " $(date --utc +%FT%T.%3NZ) Current comission: $comission_current" >>"$log_path"
}

function get_sequence() {
    sequence_c=$(umeed query account "$address" --node "$RPC" --chain-id "$CHAIN" --output json | jq -Mrc .sequence)
    sequence_x=$((sequence_c + 1))
    echo " $(date --utc +%FT%T.%3NZ) Current sequence: $sequence_c using: $sequence_x" >>"$log_path"
}

function check_tx() {
    check_this_tx="$1"
    gas_used=$(umeed query tx "$check_this_tx" --chain-id "$CHAIN" --output "json" --log_format "json" | jq -Mrc '.tx.auth_info.fee.amount[] | .amount')
    echo " $(date --utc +%FT%T.%3NZ) Fees check response: $gas_used" >>"$log_path"
}

function withdraw_comission() {

    echo " $(date --utc +%FT%T.%3NZ) Withdraw comission now, available: $comission_current" >>"$log_path"

    gas_used="unknown"

    get_current_balance

    saved_balance="$balance_current"

    get_sequence

    comission_tx=$(umeed tx distribution withdraw-rewards "$valoper" --commission --yes \
        --from "$address" "${gas_schemea}" \
        --keyring-backend "test" \
        --sequence "$sequence_c" \
        --broadcast-mode "$broadcast_method" \
        --chain-id "$CHAIN" \
        --node "$RPC" | jq -Mrc .txhash)

    if ! [ ${#comission_tx} -eq 64 ]; then

        echo " $(date --utc +%FT%T.%3NZ) ERROR: Invalid transaction output, messing sequence ..." >>"$log_path"

        sleep "$sequence_change"

        comission_tx=$(umeed tx distribution withdraw-rewards "$valoper" --commission --yes \
            --from "$address" "${gas_schemea}" \
            --keyring-backend "test" \
            --sequence "$sequence_x" \
            --broadcast-mode "$broadcast_method" \
            --chain-id "$CHAIN" \
            --node "$RPC" | jq -Mrc .txhash)

    fi

    if ! [ ${#comission_tx} -eq 64 ]; then
        echo " $(date --utc +%FT%T.%3NZ) ERROR: Invalid transaction output, return ..." >>"$log_path"
        sleep 60 && return
    fi

    echo " $(date --utc +%FT%T.%3NZ) Comission withdraw TX: $comission_tx" >>"$log_path"

    echo " $(date --utc +%FT%T.%3NZ) Waiting for comission hit our input ..." >>"$log_path"

    sleep 7

    i=0

    while true; do

        get_current_balance

        if [[ "$balance_current" -gt $saved_balance ]]; then

            profit=$((balance_current - saved_balance))

            echo " $(date --utc +%FT%T.%3NZ) Balance increased, profit: $profit" >>"$log_path"

            sleep 8

            check_tx "$comission_tx"

            if ! [[ "$gas_used" =~ $numba ]]; then

                echo " $(date --utc +%FT%T.%3NZ) ERROR: Can't fee from provided transaction, sounds impossible ..." >>"$log_path"
                echo " $(date --utc +%FT%T.%3NZ) Fee: unknown" >>"$log_path"

                break

            fi

            echo " Fee: $gas_used uumee"

            break

        fi

        sleep 7

        i=$((i + 1))

        if [[ "$i" -ge 10 ]]; then
            echo " $(date --utc +%FT%T.%3NZ) Balance did not increase, it looks like transaction failed, return ..." >>"$log_path"
            break
        fi

        echo " $(date --utc +%FT%T.%3NZ) Balance check loop counter: $i" >>"$log_path"

    done

}

function withdraw_reward() {

    echo " $(date --utc +%FT%T.%3NZ) Withdrawing reward now, available: $reward_current" >>"$log_path"

    gas_used="unknown"

    get_current_balance

    saved_balance="$balance_current"

    get_sequence

    reward_tx=$(umeed tx distribution withdraw-all-rewards \
        --from "$address" --yes "${gas_schemea}" \
        --keyring-backend "test" \
        --sequence "$sequence_c" \
        --broadcast-mode "$broadcast_method" \
        --chain-id "$CHAIN" \
        --node "$RPC" | jq -Mrc .txhash)

    if ! [[ ${#reward_tx} -eq 64 ]]; then
        echo " $(date --utc +%FT%T.%3NZ) ERROR: Invalid transaction output, messing sequence ..." >>"$log_path"

        sleep "$sequence_change"

        reward_tx=$(umeed tx distribution withdraw-all-rewards \
            --from "$address" --yes "${gas_schemea}" \
            --keyring-backend "test" \
            --sequence "$sequence_x" \
            --broadcast-mode "$broadcast_method" \
            --chain-id "$CHAIN" \
            --node "$RPC" | jq -Mrc .txhash)

    fi

    if ! [[ ${#reward_tx} -eq 64 ]]; then
        echo " $(date --utc +%FT%T.%3NZ) ERROR: Invalid transaction output, return ..." >>"$log_path"
        sleep 60 && return
    fi

    echo " $(date --utc +%FT%T.%3NZ) Reward withdraw TX: $reward_tx" >>"$log_path"

    echo " $(date --utc +%FT%T.%3NZ) Waiting for reward hit our input ..." >>"$log_path"

    sleep "$wait_for_reward"

    i=0

    while true; do

        get_current_balance

        if [[ "$balance_current" -gt $saved_balance ]]; then

            profit=$((balance_current - saved_balance))

            echo " $(date --utc +%FT%T.%3NZ) Balance increased, profit: $profit" >>"$log_path"

            sleep "$balance_increase_check_comission"

            check_tx "$comission_tx"

            if ! [[ "$gas_used" =~ $numba ]]; then

                echo " $(date --utc +%FT%T.%3NZ) ERROR: Can't get fee from provided transaction, sounds impossible ..." >>"$log_path"
                echo " $(date --utc +%FT%T.%3NZ) Fee: unknown" >>"$log_path"

                break

            fi

            echo " $(date --utc +%FT%T.%3NZ) Fee: $gas_used uumee" >>"$log_path"

            break

        fi

        sleep "$wait_for_reward_in_loop"

        i=$((i + 1))

        if [[ "$i" -ge 10 ]]; then
            echo " $(date --utc +%FT%T.%3NZ) Balance did not increase, it looks like transaction failed, return ..." >>"$log_path"
            break
        fi

        echo " $(date --utc +%FT%T.%3NZ) Balance check loop counter: $i" >>"$log_path"

    done

}

function delegate() {

    get_validator_state

    saved_bond="$tokens_bonded" # save it so we can compare later

    echo " $(date --utc +%FT%T.%3NZ) About to delegate $delegation_amount on $valoper" >>"$log_path"

    gas_used="unknown"

    get_sequence

    bond_amount="$1"

    delegation_tx=$(umeed tx staking delegate "$valoper" "$bond_amount"uumee \
        --from "$address" --yes "${gas_schemea}" \
        --keyring-backend "test" \
        --sequence "$sequence_c" \
        --broadcast-mode "$broadcast_method" \
        --chain-id "$CHAIN" \
        --node "$RPC" | jq -Mrc .txhash)

    if ! [[ ${#delegation_tx} -eq 64 ]]; then

        echo " $(date --utc +%FT%T.%3NZ) ERROR: Invalid transaction output, messing sequence ..." >>"$log_path"

        sleep "$sequence_change"

        delegation_tx=$(umeed tx staking delegate "$valoper" "$bond_amount"uumee \
            --from "$address" --yes "${gas_schemea}" \
            --keyring-backend "test" \
            --sequence "$sequence_x" \
            --broadcast-mode "$broadcast_method" \
            --chain-id "$CHAIN" \
            --node "$RPC" | jq -Mrc .txhash)

    fi

    if ! [[ ${#delegation_tx} -eq 64 ]]; then
        echo " $(date --utc +%FT%T.%3NZ) ERROR: Invalid transaction output, return and retry ..." >>"$log_path"
        sleep 8 && return
    fi

    echo " $(date --utc +%FT%T.%3NZ) Waiting for successfull delegation: $delegation_tx" >>"$log_path"

    sleep $waiting_for_delegation # we really want delegation to hit here, otherwise extra wait time will be introduced

    i=0

    while true; do

        get_validator_state # lets check if it works actually

        bond_diff=$((tokens_bonded - saved_bond)) # calculate if we get any profit

        if [[ $bond_diff -ge 10 ]]; then
            echo " $(date --utc +%FT%T.%3NZ) Success !" >>"$log_path"
            break
        fi

        i=$((i + 1))

        echo " $(date --utc +%FT%T.%3NZ) Loop increment $i" >>"$log_path"

        if [[ "$i" -ge 25 ]]; then
            echo " $(date --utc +%FT%T.%3NZ) ERROR: Delegation transaction can't go trough after $i attempts, return ..." >>"$log_path"
            break
        fi

        echo " $(date --utc +%FT%T.%3NZ) Sleeping for 3 seconds ..." >>"$log_path"

        sleep "$delegation_loop_wait"

    done

    echo " $(date --utc +%FT%T.%3NZ) Initial bond: $saved_bond, current: $tokens_bonded, gain this time: $bond_diff" >>"$log_path"

    echo " $(date --utc +%FT%T.%3NZ) -------------------" >>"$log_path"
    echo " $(date --utc +%FT%T.%3NZ) Sequence complete !" >>"$log_path"
    echo " $(date --utc +%FT%T.%3NZ) -------------------" >>"$log_path"

}

function get_validator_state() {

    echo " $(date --utc +%FT%T.%3NZ) Checking validator statistics ..." >>"$log_path"

    missed_blocks=$(umeed query slashing signing-info "$UMEE_VAL_CONS_PUB" --chain-id "$CHAIN" --node "$RPC" -o json | jq -Mrc .missed_blocks_counter)

    if [[ $missed_blocks -ge 10 ]]; then
        echo " $(date --utc +%FT%T.%3NZ) Ahtung ! Missed blocks: $missed_blocks" >>"$log_path"
    else
        echo " $(date --utc +%FT%T.%3NZ) Missed blocks: $missed_blocks" >>"$log_path"
    fi

    staking_data=$(umeed query staking validator "$valoper" --node "$RPC" --chain-id "$CHAIN" -o json)

    jail_state=$(echo "$staking_data" | jq -r .jailed)

    if ! [[ "$jail_state" =~ false ]]; then
        echo " $(date --utc +%FT%T.%3NZ) FATAL: Validator jailed !" >>"$log_path"
        exit 1
    fi

    tokens_bonded=$(echo "$staking_data" | jq -r .tokens)

    echo " $(date --utc +%FT%T.%3NZ) Tokens bonded: $tokens_bonded" >>"$log_path"

}

function main() {

    while true; do

        echo " $(date --utc +%FT%T.%3NZ) --------------------------" >>"$log_path"
        get_current_reward
        get_current_comission
        get_current_balance
        echo " $(date --utc +%FT%T.%3NZ) --------------------------" >>"$log_path"

        if [[ "$reward_current" -gt $reward_threshold ]]; then
            withdraw_reward
        fi

        if [[ "$comission_current" -gt $comission_threshold ]]; then
            echo " $(date --utc +%FT%T.%3NZ) Comission profit is above: $comission_threshold, available for withdraw: $comission_current, processing ..." >>"$log_path"
            withdraw_comission
        fi

        if [[ "$balance_current" -gt $balance_treshold ]]; then
            delegation_amount=$((balance_current - keep_for_comission))
            echo " $(date --utc +%FT%T.%3NZ) Available for delegation: $delegation_amount" >>"$log_path"
            delegate "$delegation_amount"
        fi

        echo " $(date --utc +%FT%T.%3NZ) ******** MAIN LOOP *******" >>"$log_path"
        echo " $(date --utc +%FT%T.%3NZ) --------------------------" >>"$log_path"

        sleep "$main_loop_interval"

    done

}

get_address

main
