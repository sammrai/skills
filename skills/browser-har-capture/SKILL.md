---
name: browser-har-capture
description: Record and verify browser network traffic as HAR to investigate or implement web application functionality, including multi-page workflows and authenticated sites.
---

# Browser HAR capture

## Scope and coverage

Determine the requested functionality and check existing captures before recording. Capture the distinct operations, conditions, and states that change requests or responses, such as navigation, search, filtering, pagination, details, and relevant error or empty states. Verify that the target requests and successful response bodies are present. An existing capture need not be repeated merely because data or time has changed if it covers the required behavior.

Distinguish recording how to retrieve data from checking what data is available under a particular condition or at a particular time. Verify the latter using retrieved results; a HAR alone does not prove implementation or validation is complete. Capture additional traffic when behavior differs, existing evidence is insufficient, or a specific capture condition was requested.

## Record

1. Identify the intended browser tab and confirm the Network panel belongs to it. Enable recording, preserve the log across navigation, and include the relevant request types.
2. Perform the requested actions and verify the expected screens and results. Note the operation order, relevant inputs and conditions, and timestamps without exposing sensitive data. Cover each requested behavior; do not silently narrow the scope.
3. A separate tab or window does not automatically appear in the original tab's log. Record its traffic separately or reproduce the original workflow in the recording tab when this preserves its method and state. Do not replace a stateful or POST workflow with an unverified direct GET.
4. Export the appropriate HAR. Handle authenticated or sensitive captures according to the user's authorization and chosen private storage location. Never expose credentials, session tokens, account details, or HAR bodies in status messages.
5. Verify the saved file exists, is parseable, and contains the expected requests, statuses, and response bodies for each operation. A URL or a success status alone does not prove the desired data was captured. Record incomplete or unavailable portions accurately.
6. If transfer is requested, copy to the specified destination and verify integrity against the source. Keep sensitive files out of version control and public sharing.

## Handoff

When asked to hand off, communicate the user's request, verified capture scope, file locations, and material gaps. Track capture, transfer, and handoff separately. If using an interactive terminal session, verify the destination before sending and inspect the sent history and recipient acknowledgment or processing; distinguish sent-but-unconfirmed from received. Avoid duplicate messages and respect any requested batching.
