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

TEST_MODE=${TEST_MODE:-'true'}
PORT=${PORT:-3000}
MONGO_PORT=${MONGO_PORT:-27017}
MONGO_DB=${MONGO_DB:-'rocketchat'}
MONGO_URL=${MONGO_URL:-"mongodb://localhost:${MONGO_PORT}/${MONGO_DB}?directConnection=true"}

TEST_MODE=$TEST_MODE \
MONGO_URL=$MONGO_URL \
PORT=$PORT \
ROOT_URL="http://localhost:${PORT}" \
OVERWRITE_SETTING_Enterprise_License='Uo7Jcr6WW0XYA8ydHd+Sk6pZ9/0V6dIASnyTwvUrNym/zJg2Ma3eYNKkC8osXLCc72y1ahohnWY7/+7IYkvono3GYXQR+IGvYbbrVgNR6OjMahd9P/odHZL1GFTm2qHrEL5Hh/XEOG+YluFeRdWPzCizQlp4zGGOi0+PkQo096TR9NVCLrsErVl2MW1WM6ZM1W5EUJG9pKly4BQnaOTUAlor1im6i8qPTDCKrISZfLiZEWuQKaPW/GE3mRKjQNjDh0CabX1N2S880pRRGoozBYAnp2NmFfrQW0+5ihKisBTIeMbMZ7K5NE5PkYU1nhQDcc+rpDHtwG9Ceg5X0J+oea3UfrPTmDON2aSI0iO22kvL6G7QI3fyrEIvJrMbxcNKxAFeQYgnjisw/b06+chWSG4jG686Fx58XrVS87dFhWL9WoGltsk1dJCntUQvI1sX6zOfpvyg1iWRnHfYDOrwoWlX57XMm29fWineEoqnOOTOVnA/uP+DKEhercQ9Xuo7Cr6zJxpQpwd03e7ODVjiEbTDqlkZE687rmxRCD4Wmu8L86WIl2xSEIajKLX301Ww5mz/FdLqk+Mg32lkW66W3azQKvJ1440NBrYxhpJ+dl9vSFMb3s1+xnz1cYUbjUcq9mARvORcgy5mLwKulmqT6Sq0Uvbv10YCO0TW0beXYW8=' \
OVERWRITE_SETTING_Log_Level='2' \
OVERWRITE_SETTING_Show_Setup_Wizard='completed' \
OVERWRITE_SETTING_Accounts_Password_Policy_Enabled='false' \
OVERWRITE_SETTING_Accounts_TwoFactorAuthentication_Enabled='false' \
OVERWRITE_SETTING_Cloud_Url='https://my.staging.cloud.rocket.chat' \
OVERWRITE_SETTING_Cloud_Billing_Url='https://billing.staging.cloud.rocket.chat' \
OVERWRITE_INTERNAL_MARKETPLACE_URL='https://marketplace.staging.cloud.rocket.chat' \
script --quiet --flush --return --log-out $_WATCHRC_pipe --command "node ${NODE_FLAGS[@]} $SCRIPT"

# `script` will run the --command, write output to stdout AND to --log-out (maintaining colors) and set its exit code to --return
