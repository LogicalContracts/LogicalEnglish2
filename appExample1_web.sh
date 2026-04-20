#!/bin/bash

# Logical English Web API Example Client
# This script tests the classic_web_api.pl using curl.

# How to run this test:
# 1.  Start the server:
#        swipl -g "use_module(classic_web_api), start_api_server(3053)"
# 2.  Run the client script:
#        ./appExample1_web.sh

PORT=3053
URL="http://localhost:$PORT/leapi"
TOKEN="myToken123"

# Function to make a POST request
le_post() {
    if command -v jq >/dev/null 2>&1; then
        curl -s -X POST "$URL" \
            -H 'Content-Type: application/json' \
            -d "$1" | jq .
    else
        curl -s -X POST "$URL" \
            -H 'Content-Type: application/json' \
            -d "$1"
    fi
}

# Function to extract session ID without jq
extract_session() {
    echo "$1" | grep -o '"sessionModule":"[^"]*"' | cut -d'"' -f4
}

echo "--- Starting Logical English Web API Test ---"

# 1. Load the citizenship example
echo "1. Loading 'citizenship' example..."
LOAD_DATA=$(cat <<EOF
{
    "token": "$TOKEN",
    "operation": "load",
    "file": "citizenship"
}
EOF
)
LOAD_RESP=$(curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$LOAD_DATA")
SESSION=$(extract_session "$LOAD_RESP")

if [ -z "$SESSION" ]; then
    echo "Failed to load KB. Response: $LOAD_RESP"
    exit 1
fi
echo "Session created: $SESSION"
if command -v jq >/dev/null 2>&1; then
    echo "$LOAD_RESP" | jq .
else
    echo "$LOAD_RESP"
fi
echo "Session created: $SESSION"
if command -v jq >/dev/null 2>&1; then
    echo "$LOAD_RESP" | jq .
else
    echo "$LOAD_RESP"
fi

# 2. Run a query with a scenario
echo -e "\n2. Running query: 'which person acquires British citizenship on which date' with scenario 'alice'..."
QUERY_DATA=$(cat <<EOF
{
    "token": "$TOKEN",
    "operation": "answeringQuery",
    "sessionModule": "$SESSION",
    "scenario": "alice",
    "query": "which person acquires British citizenship on which date"
}
EOF
)
le_post "$QUERY_DATA"

# 3. Load facts and run a goal
echo -e "\n\n3. Loading custom facts and running a goal..."
FACTS_DATA=$(cat <<EOF
{
    "token": "$TOKEN",
    "operation": "loadFactsAndQuery",
    "sessionModule": "$SESSION",
    "facts": ["is_a('Alice', 'person')", "is_a('Bob', 'person')"],
    "goal": "is_a(X, 'person')",
    "vars": ["X"]
}
EOF
)
le_post "$FACTS_DATA"

# 4. Low-level query
echo -e "\n\n4. Running low-level query..."
LOW_LEVEL_DATA=$(cat <<EOF
{
    "token": "$TOKEN",
    "operation": "query",
    "module": "$SESSION",
    "theQuery": "is_a(Who, 'person')"
}
EOF
)
le_post "$LOW_LEVEL_DATA"

# 5. Retrieve example document
echo -e "\n\n5. Retrieving example document '1_net_asset_value_test_3'..."
EXAMPLE_DATA=$(cat <<EOF
{
    "token": "$TOKEN",
    "operation": "examples",
    "file": "1_net_asset_value_test_3"
}
EOF
)
le_post "$EXAMPLE_DATA" | cut -c 1-100 | sed 's/$/.../'

echo -e "\n\n--- Test Complete ---"
