# Phase 1 Evolution: Implementation Plan

## 1. Objectives
- Eliminate memory-heavy Base64 uploads.
- Establish Hive-based offline foundation.
- Implement reliable Sync Engine.
- Transition Agent to multi-turn conversation.
- Add voice input capabilities.
- Maintain full backward compatibility with existing BLoC and Firestore logic.

## 2. Technical Changes

### A. Upload Migration Strategy
1. **Flutter Implementation**:
   - Add `firebase_storage` and `crypto` packages.
   - Refactor `HaulRepository` and `HandoffRepository`.
   - Before calling `onGate1Confirm` or `onGate2Confirm`, upload the image to `handoffs/{handoffId}/gate{1|2}.jpg`.
   - Calculate SHA-256 hash of the image bytes locally.
   - Pass `imageUrl` and `imageHash` to the Cloud Function.
2. **Backend Implementation**:
   - Update `onGate1Confirm` and `onGate2Confirm` functions to accept `imageUrl` and `imageHash`.
   - Remove `Buffer.from(base64)` and manual storage save logic.

### B. Offline & Sync Foundation
1. **Hive Boxes**:
   - `pendingActions`: Queue for Cloud Function calls (Gate confirmations, Listings).
   - `pendingUploads`: Queue for file uploads to Firebase Storage.
   - `conversationDrafts`: Persist active conversation state locally.
2. **SyncEngine**:
   - Background service that monitors connectivity.
   - Retries `pendingUploads` first, then `pendingActions`.
   - Implements exponential backoff and idempotency checks.

### C. Conversational Agent
1. **Firestore Schema Extension**:
   - New collection: `/conversations/{conversationId}`.
   - Schema: `growerId`, `messages[]`, `extractedFields`, `missingFields[]`, `status`, `lastUpdatedAt`.
2. **Backend**:
   - New function: `processConversationTurn`.
   - Logic: Extracts fields -> Merges with history -> Identifies missing fields -> Generates follow-up question.
3. **AgentBloc**:
   - Add `SendConversationMessage`, `LoadConversation` events.
   - Add `ConversationActive`, `ConversationThinking` states.
   - Preserve `AgentNeedsReview` as the final "Confirmation Gate".

### D. Voice Foundation
1. **Packages**: `speech_to_text`, `flutter_tts`, `record`.
2. **UI**: Add Microphone button to `AgentScreen`.
3. **Flow**: Speech -> Text -> `SendConversationMessage`.

## 3. Detailed Architecture Diagram (Mental Model)
[User Input/Voice] -> [AgentBloc] -> [SyncEngine] -> [Hive (Offline Queue)]
                                         |
                                         V
[Cloud Function: processConversationTurn] <-> [Firestore: /conversations]
                                         |
                                         V
[AgentNeedsReview (State)] -> [User Confirm] -> [Firestore: /listings]

## 4. Implementation Order
1. **Step 1**: Add dependencies to `pubspec.yaml` for all apps.
2. **Step 2**: Implement Hive models and boxes in `packages/core` or shared location.
3. **Step 3**: Update `onGate1Confirm` and `onGate2Confirm` backend functions.
4. **Step 4**: Update `HaulRepository` and `HandoffRepository` with storage-first flow.
5. **Step 5**: Create `processConversationTurn` backend function.
6. **Step 7**: Extend `AgentBloc` and update `AgentScreen`.
7. **Step 8**: Implement `SyncEngine` for offline reliability.
8. **Step 9**: Add Voice input logic.

## 5. Risk Analysis & Compatibility
- **Backward Compatibility**: Existing listings are unaffected. Existing `agentProcessListing` function remains for single-shot entry if needed, but `AgentBloc` will favor conversational turns.
- **Risk**: Image upload failure before function call. **Mitigation**: SyncEngine handles retries of both upload and function call as a unit of work.
- **Risk**: AI Hallucinations in multi-turn. **Mitigation**: Preserve existing `AgentNeedsReview` UI which forces human verification of all extracted data.
