---
name: browser-har-capture
description: Record and verify browser network traffic as HAR to investigate or implement web application functionality, including multi-page workflows and authenticated sites.
---

# Browser HAR capture

## Scope and coverage

Determine the requested functionality and check existing captures before recording. Capture the distinct operations, conditions, and states that change requests or responses, such as navigation, search, filtering, pagination, details, and relevant error or empty states. Verify that the target requests and successful response bodies are present. An existing capture need not be repeated merely because data or time has changed if it covers the required behavior.

Distinguish recording how to retrieve data from checking what data is available under a particular condition or at a particular time. Verify the latter using retrieved results; a HAR alone does not prove implementation or validation is complete. Capture additional traffic when behavior differs, existing evidence is insufficient, or a specific capture condition was requested.

## Record

1. Select the correct browser tab and open Developer Tools → **Network**. Confirm the recording control is active (its action says “Stop recording”); start it if necessary. Enable **Preserve log / Keep log**, clear the text filter, and select **All** request types. If clearing an old log, first confirm it belongs to the intended tab and does not contain required unsaved traffic.
2. Perform the requested actions. After navigation or search, confirm new requests appear in that Network panel and that the intended screen and result are visible. Record the operation order, relevant inputs and conditions, and timestamps without exposing sensitive data. Cover every requested behavior without silently narrowing the scope.
3. A separate tab or window does not automatically appear in the original tab's log. Enable Network recording in the new tab before reproducing its workflow, or reproduce it in the original tab only when doing so preserves its method and state. Do not replace a stateful or POST workflow with an unverified direct GET. Export a separate HAR if necessary.
4. Use Network → **Export HAR**. Select the sanitized export unless a sensitive capture is authorized and private storage is specified. If the browser requires an additional setting to allow sensitive exports, enable it only within that authorization. Choose a descriptive filename and location. Confirm the save dialog actually closes and the file exists; if save fails, inspect the current dialog and retry or request the necessary user action rather than assuming success.
5. Parse the saved JSON and match requests to each operation using method, path, relevant parameters, timestamps, and response status. Verify the expected response body or downloaded artifact is present and contains the relevant result; URL and HTTP 200 alone are insufficient, and some browser viewers omit response bodies from HAR. Report missing, cached, failed, or omitted responses accurately and capture again when needed.
6. If transfer is requested, copy to the specified destination and compare source and destination hashes. Track save and transfer separately. Keep captures containing credentials, session tokens, account details, or other private data out of version control, public sharing, and status messages; never paste HAR bodies or secrets into reports.

## Handoff

When asked to hand off, communicate the user's request, verified capture scope, file locations, and material gaps. Track capture, transfer, and handoff separately. If using an interactive terminal session, verify the destination before sending and inspect the sent history and recipient acknowledgment or processing; distinguish sent-but-unconfirmed from received. Avoid duplicate messages and respect any requested batching.
