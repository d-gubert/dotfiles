#!/bin/zsh

source "$(dirname $0)/watch_rocket.sh"

# Default script path
DEFAULT_SCRIPT="`pwd`/.meteor/local/build/main.js"
SCRIPT=""
NODE_FLAGS=()

# Iterate through all arguments passed to this shell script
for arg in "$@"; do
  if [[ "$arg" == -* ]]; then
    # If argument starts with "-", treat it as a Node flag
    NODE_FLAGS+=("$arg")
  else
    # Otherwise, treat it as the script path
    SCRIPT="$arg"
  fi
done

# If no script path was found in arguments, use the default
SCRIPT=${SCRIPT:-$DEFAULT_SCRIPT}

TEST_MODE=${TEST_MODE:-'api'}
PORT=${PORT:-3000}
MONGO_PORT=${MONGO_PORT:-27017}
MONGO_DB=${MONGO_DB:-'rocketchat'}
MONGO_URL=${MONGO_URL:-"mongodb://localhost:${MONGO_PORT}/${MONGO_DB}?directConnection=true"}

TEST_MODE=$TEST_MODE \
MONGO_URL=$MONGO_URL \
PORT=$PORT \
ROOT_URL="http://localhost:${PORT}" \
OVERWRITE_SETTING_Enterprise_License='MK+bpK5NveUuNlWGaQXGoy+8b74Luet82M3ZGcBB8b5P9Y+m67NEtpW64dc1d5lEWi6d0nFjCjtCMneVD7bKxodz/Cml8URKEo5P7cQb/9wmeT0MzAhYNaRFZlIGkZ3ITF59pDV2u4HZuosEDJikVRwnaJ5ZoU/pOsHSPUPhTyGNIqLeKynODtUpfwDdIKEmHxpf2yVkKjgRiIJmbWjM6A4k+MNNYXWVXHzye7GggqWVg/ZcT7nKU1CCadpLhTJiIrgrrPzil1G5DQ4xnLs3Q2tu2dILSDiW5OYw/ywu2yCMicTjMq4MLL5SXDQJj6WoJzZ54HosbvsDzOXvsdC9gI1CjhPL2uRuvC8XLrzn3vL2UgXnifzD1VrLTtdZ+aSADveqtlzYlRWtqoUFBbNw8o+YVHdhbZGR0beMoAyRbHi5EMpxpad3L+NyztUIT/Uh/IjQ/C2SQZ6jB0GKPBOPxFLN56FNhTGrffLFR++TVoBu0Iquc7kajWkNit3bVbZvbx+oFcVW2PcjQ/+i2jpJjbgtUFUKrTKxGMAXTWoDzIQQ35zNzGAy268IM4Ymp5JmsVEnBOEUkbF9yx6fzkO6xZhpsHf0muklnW0kA+Tlore/TUrBWh1/RwWlQeZlxM5NyWoRM5onQmr/k/4BmObtL1Hpmbk8oMG29z89xtE9y/4=' \
OVERWRITE_SETTING_Log_Level='2' \
OVERWRITE_SETTING_Show_Setup_Wizard='completed' \
OVERWRITE_SETTING_Accounts_Password_Policy_Enabled='false' \
OVERWRITE_SETTING_Accounts_TwoFactorAuthentication_Enabled='false' \
OVERWRITE_SETTING_Cloud_Url='https://my.staging.cloud.rocket.chat' \
OVERWRITE_SETTING_Cloud_Billing_Url='https://billing.staging.cloud.rocket.chat' \
OVERWRITE_INTERNAL_MARKETPLACE_URL='https://marketplace.staging.cloud.rocket.chat' \
script --quiet --flush --return --log-out $_WATCHRC_pipe --command "node ${NODE_FLAGS[@]} $SCRIPT"

# `script` will run the --command, write output to stdout AND to --log-out (maintaining colors) and set its exit code to --return
