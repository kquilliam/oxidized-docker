#!/bin/bash

# --- Configuration ---
SYSLOG_SERVER="10.242.0.116"
SYSLOG_TAG="oxidized-events"
# ---------------------

# If the node name is empty, exit immediately.
if [ -z "$OX_NODE_NAME" ]; then
  exit 0
fi

# This script uses the corrected variable names ($OX_EVENT, $OX_NODE_NAME, etc.)
case "$OX_EVENT" in
  node_success)
    MESSAGE="SUCCESS: Successfully backed up node '$OX_NODE_NAME'."
    logger -n "$SYSLOG_SERVER" -t "$SYSLOG_TAG" -p local1.info "$MESSAGE"
    ;;

  node_fail)
    MESSAGE="FAILURE: Failed to back up node '$OX_NODE_NAME'. Reason: $OX_JOB_STATUS."
    logger -n "$SYSLOG_SERVER" -t "$SYSLOG_TAG" -p local1.error "$MESSAGE"
    ;;

  post_store)
    MESSAGE="STORED: A new configuration for node '$OX_NODE_NAME' has been saved."
    logger -n "$SYSLOG_SERVER" -t "$SYSLOG_TAG" -p local1.notice "$MESSAGE"
    ;;
    
  *)
    # This is a catch-all for any other events.
    MESSAGE="INFO: Received unhandled event '$OX_EVENT' for node '$OX_NODE_NAME'."
    logger -n "$SYSLOG_SERVER" -t "$SYSLOG_TAG" -p local1.debug "$MESSAGE"
    ;;
esac

exit 0
