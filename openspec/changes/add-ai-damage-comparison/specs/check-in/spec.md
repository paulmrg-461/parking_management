## ADDED Requirements

### Requirement: Guided photo capture
The check-in form SHALL show a non-blocking guidance banner and angle chips above the evidence photo strip that name the next suggested angle (front-left, front-right, rear-right, rear-left, then a close-up of any damage) and offer an illustration with the capture rules (about 3 m away, whole vehicle in frame, avoid backlight, repeat the same corners at exit). The guidance MUST be UI-only: it MUST NOT make photos mandatory, change the number or size limits of photos, change the upload paths, or change the parameters of the `check_in` RPC.

#### Scenario: Banner names the next angle
- **WHEN** the operator has captured one photo
- **THEN** the banner reads "Next photo: front-right corner" in the app language and the first chip is marked as captured

#### Scenario: Check-in without photos still works
- **WHEN** the operator submits the check-in with no photos
- **THEN** the check-in succeeds exactly as before

#### Scenario: Submission payload unchanged
- **WHEN** the operator submits with three photos
- **THEN** the photos and RPC parameters sent are the same as before this change
