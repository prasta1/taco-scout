# App Store Submission Plan — TacoScout 1.24 (build 4)

> **For agentic workers:** This is a release checklist, not a code implementation plan. Work through each step in order; do not skip or batch steps.

**Goal:** Submit TacoScout 1.24 (build 4) to App Store Review.

**Context:** Build 3 was bumped at commit `55fe003`, but 7 additional commits landed after that (filter-reset pill, location fix, widget deep link fix, VoiceOver labels, screenshot updates). Build must be incremented to 4 before archiving.

**Marketing version:** 1.24 (no change needed — the features justify the minor version)

---

## Phase 1 — Pre-flight

### Task 1: Device smoke-test the two open TODOs

These are flagged in `TODO.md` and need manual verification before submission.

- [ ] **Step 1: Test feedback links in Settings**

  On a real device (not simulator): Settings → Feedback & Ideas → tap "Report a Bug" and "Request a Feature". Verify Mail opens with pre-filled subject + body for each.

- [ ] **Step 2: Test "Rate TacoScout" in Settings**

  On a real device: Settings → tap "Rate TacoScout". Verify the in-app App Store review prompt appears (SKStoreReviewController). Note: this will not trigger if the device has already rated — test on a clean device or simulator if needed.

- [ ] **Step 3: Log results**

  If either check fails, fix it before proceeding. If both pass, move to Task 2.

---

### Task 2: Bump build number

The project has two targets with separate build numbers. Both must be incremented.

**Files to edit:** `TacoScout.xcodeproj/project.pbxproj`

Use Xcode's target editor (not direct file edits) to avoid corrupting the pbxproj:

- [ ] **Step 1: Open TacoScout target build settings**

  Xcode → TacoScout target → General tab → Identity section:
  - Marketing Version: **1.24** (no change)
  - Build: change **3 → 4**

- [ ] **Step 2: Open TacoScoutWidget target build settings**

  Xcode → TacoScoutWidget target → General tab → Identity section:
  - Build: change **2 → 3** (or match whatever Apple requires — widget build must be ≤ app build)

- [ ] **Step 3: Verify in project.pbxproj**

  ```bash
  grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" TacoScout.xcodeproj/project.pbxproj | sort -u
  ```

  Expected:
  ```
  CURRENT_PROJECT_VERSION = 4;   ← main app
  CURRENT_PROJECT_VERSION = 3;   ← widget (or same as app)
  MARKETING_VERSION = 1.24;
  ```

- [ ] **Step 4: Commit the build bump**

  ```bash
  git add TacoScout.xcodeproj/project.pbxproj
  git commit -m "Bump to 1.24 (build 4)"
  ```

---

## Phase 2 — Build & Archive

### Task 3: Clean build

- [ ] **Step 1: Clean derived data**

  Xcode → Product → Clean Build Folder (Shift+Cmd+K)

- [ ] **Step 2: Build for a simulator to confirm no compiler errors**

  Xcode → select any iPhone simulator → Cmd+B

  Expected: Build Succeeded, zero errors.

  If errors appear, fix them before archiving.

---

### Task 4: Archive

- [ ] **Step 1: Select "Any iOS Device (arm64)" as the run destination**

  This is required — archiving for a simulator is not valid for submission.

- [ ] **Step 2: Archive**

  Xcode → Product → Archive

  This will take several minutes. Watch for any signing errors.

- [ ] **Step 3: Verify archive appears in Organizer**

  Xcode → Window → Organizer → Archives tab. Confirm a new TacoScout 1.24 (4) archive appears dated today.

---

## Phase 3 — Upload

### Task 5: Distribute to App Store Connect

- [ ] **Step 1: Open Organizer and select the archive**

  Window → Organizer → select today's archive → Distribute App

- [ ] **Step 2: Choose distribution method**

  Select: **App Store Connect** → Next

- [ ] **Step 3: Distribution options**

  - Upload: **✓ Upload**
  - Strip Swift Symbols: **✓** (recommended)
  - Include bitcode: leave as default

- [ ] **Step 4: Review and upload**

  Confirm signing certificate and provisioning profile are correct, then click Upload.

  Upload typically takes 2–5 minutes. Xcode will show "Upload Successful" when done.

- [ ] **Step 5: Wait for processing**

  App Store Connect processes new builds for ~15–30 minutes. You'll get an email when processing completes. Do not proceed to submission until the build shows as "Ready to Submit" in ASC.

---

## Phase 4 — App Store Connect Configuration

### Task 6: Configure the submission

Log in to [App Store Connect](https://appstoreconnect.apple.com) → My Apps → TacoScout.

- [ ] **Step 1: Verify build is attached**

  Under the iOS App section for the 1.24 submission, confirm build 4 is selected. If not, click "+" next to the build number and select it.

- [ ] **Step 2: Write "What's New in This Version" text**

  Suggested copy (edit to taste):
  ```
  • Filter reset: a new pill button clears all active search filters at once
  • Fixed a bug where the location permission prompt appeared twice on first launch
  • Fixed the Lucky Pick widget deep link and several other latency correctness issues
  • Improved VoiceOver accessibility labels throughout
  ```

- [ ] **Step 3: Verify screenshots**

  Screenshots were updated in commit `375862e`. Confirm the correct screenshots are attached for all required device sizes (6.5" iPhone, 13" iPad at minimum).

- [ ] **Step 4: Check app metadata**

  Skim: App Name, Subtitle, Description, Keywords, Support URL, Privacy Policy URL. Update if anything is stale.

---

## Phase 5 — Submit

### Task 7: Submit for review

- [ ] **Step 1: Complete the Content Rights and Advertising Identifier declarations**

  These appear at the bottom of the App Store submission page. Confirm answers are still accurate:
  - Does this app use the Advertising Identifier (IDFA)? **No** (ads were removed in 1.1 / PR #26)
  - Content rights: confirm no third-party content issues

- [ ] **Step 2: Submit**

  Click "Add for Review" → Submit to App Review.

- [ ] **Step 3: Confirm submission status**

  The app status should change to "Waiting for Review". You'll get an email confirmation.

- [ ] **Step 4: Push and tag**

  ```bash
  git push
  git tag v1.24.4
  git push origin v1.24.4
  ```

---

## Notes

- **Review time:** Typically 24–48 hours. Check ASC for status updates.
- **Rejection recovery:** If rejected, the most common reason for this app category is location justification — ensure the NSLocationWhenInUseUsageDescription in Info.plist is accurate.
- **Widget build number:** Apple requires the widget extension build number to be ≤ the host app build number. If you get a signing/upload error about this, align both to 4.
