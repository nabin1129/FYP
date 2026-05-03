# NetraCare API Integration Test Cases

**Purpose**: Validate that the mobile app, backend APIs, and AI/ML services work together behind the scenes.

**Test Environment**: Local Flask backend with test client smoke validation

**Preconditions**:
- Backend server is running.
- A valid test user exists in the database.
- Requests include a valid Bearer token after login.

## Test Case Summary

| Test Case ID | Endpoint | Request Type | Purpose | Expected Result | Actual Result | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TC-API-001 | `/api/auth/login` | `POST` | Verify user login and JWT generation | HTTP 200 and token returned | HTTP 200 and token returned | Pass |
| TC-API-002 | `/api/auth/profile` | `GET` | Verify protected profile access using token | HTTP 200 and user profile returned | HTTP 200 and user profile returned | Pass |
| TC-API-003 | `/api/pupil-reflex/start-test` | `POST` | Start a pupil reflex test session | HTTP 201 and `test_id` returned | HTTP 201 and `test_id` returned | Pass |
| TC-API-004 | `/api/pupil-reflex/test/submit` | `POST` | Submit pupil reflex test results to backend | HTTP 201 and clinical output stored | HTTP 201 and clinical output stored | Pass |
| TC-API-005 | `/api/pupil-reflex/results/{test_id}` | `GET` | Fetch saved pupil reflex test results | HTTP 200 and result details returned | HTTP 200 and result details returned | Pass |
| TC-API-006 | `/api/ai-report/generate` | `POST` | Generate AI-powered eye health report from stored tests | HTTP 200 and report JSON returned | HTTP 200 and report JSON returned | Pass |

## Detailed Test Cases

### TC-API-001: User Login
**Objective**: Confirm that the mobile app can authenticate against the backend.

**Request**:
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "test.user@example.com",
  "password": "StrongPass1!"
}
```

**Expected**: Login succeeds and a JWT is returned.

**Result**: Passed. The backend returned HTTP 200 with a valid JWT.

### TC-API-002: Profile Access
**Objective**: Verify the returned token works on protected endpoints.

**Request**:
```http
GET /api/auth/profile
Authorization: Bearer <token>
```

**Expected**: Protected profile data is returned.

**Result**: Passed. The backend returned the authenticated user profile.

### TC-API-003: Start Pupil Reflex Test
**Objective**: Confirm the app can create a pupil reflex test session.

**Request**:
```http
POST /api/pupil-reflex/start-test
Authorization: Bearer <token>
Content-Type: application/json

{
  "test_type": "pupil_reflex",
  "eye_tested": "both"
}
```

**Expected**: HTTP 201 and a `test_id` for the session.

**Result**: Passed. The backend created the session and returned a test identifier.

### TC-API-004: Submit Pupil Reflex Results
**Objective**: Verify structured test data is accepted and stored.

**Request**:
```http
POST /api/pupil-reflex/test/submit
Authorization: Bearer <token>
Content-Type: multipart/form-data

reaction_time=0.25
constriction_amplitude=Normal
symmetry=Equal
nystagmus_detected=false
diagnosis=Normal pupil reflex
recommendations=Continue routine eye care
```

**Expected**: HTTP 201 and saved clinical output fields.

**Result**: Passed. The backend stored the test and returned clinical output metadata.

### TC-API-005: Retrieve Pupil Reflex Results
**Objective**: Confirm that stored test results can be fetched later by the app.

**Request**:
```http
GET /api/pupil-reflex/results/{test_id}
Authorization: Bearer <token>
```

**Expected**: HTTP 200 and the saved result payload.

**Result**: Passed. The backend returned the stored test result and clinical summary.

### TC-API-006: Generate AI Report
**Objective**: Verify the AI/ML reporting pipeline works behind the mobile app.

**Request**:
```http
POST /api/ai-report/generate
Authorization: Bearer <token>
Content-Type: application/json

{
  "time_range_days": 30
}
```

**Expected**: HTTP 200 and a generated AI report JSON.

**Result**: Passed. The backend generated the report successfully using fallback mode because Gemini was not configured in the local environment.

## Validation Note

The integration flow was validated end to end in the backend test client. The critical issue discovered during testing was that the v2 auth login endpoint originally produced JWTs without `iat` and `sub`, which caused protected routes to reject the token. That issue was fixed before final validation.

## About The Fix

The v2 authentication namespace was updated so `/api/auth/login` now returns JWTs with the standard `sub`, `iat`, and `exp` claims. This matters because the shared `token_required` middleware used across protected endpoints validates those claims before allowing access.

In practice, this means the mobile app can now log in through the v2 auth API and reuse the same token on protected routes such as `/api/auth/profile` and `/api/pupil-reflex/*` without authentication errors. The helper is implemented in `auth_routes.py` and used directly inside the login handler.