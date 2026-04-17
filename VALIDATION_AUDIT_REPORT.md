# NetraCare Login & Sign Up Form Validation Audit Report
**Date**: April 10, 2026  
**Review Level**: Senior Flutter Developer  
**Status**: ⚠️ CRITICAL ISSUES FOUND

---

## Executive Summary
The current Login & Sign Up implementation has **moderate** form validation but **critical gaps** in security, error handling, and edge cases. This report details all issues found against the 8-category validation checklist and provides fixes.

---

## 1. INPUT VALIDATION ERRORS - Client & Server Side

### ✅ WORKING
- Basic empty field validation on login (email/password required)
- Signup has name, email, password field validation
- Password visibility toggle on both forms

### ❌ CRITICAL ISSUES

#### Issue 1.1: **Email Validation Too Permissive**
**Severity**: HIGH  
**Location**: `signup_page.dart` line ~150
```dart
validator: (v) => v == null || !v.contains('@')
    ? 'Valid email required'
    : null,
```
**Problem**: Only checks for `@` symbol. Allows:
- `test@` (missing domain)
- `@test.com` (missing local part)
- `test@@example.com` (double @)
- `test@example` (missing TLD)

**Fix**: Use proper email regex validation
```dart
static bool isValidEmail(String email) {
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  return emailRegex.hasMatch(email);
}
```

#### Issue 1.2: **Input Field Trimming Inconsistency**
**Severity**: MEDIUM  
**Location**: Multiple files
**Problem**: 
- Login: `_emailController.text.trim()` ✓
- Signup: `emailController.text.trim()` but also `nameController.text.trim()` ✓
- BUT: No trim on any input field validators

**Impact**: User with "  user@gmail.com  " passes validation, then backend rejects or creates duplicate account

**Fix**: Add trim() in all validators:
```dart
validator: (v) {
  final trimmed = v?.trim() ?? '';
  if (trimmed.isEmpty) return 'Email required';
  if (!isValidEmail(trimmed)) return 'Invalid email format';
  return null;
}
```

#### Issue 1.3: **Weak Password Validation**
**Severity**: CRITICAL  
**Signup Location**: `signup_page.dart` lines 20-26
```dart
bool isStrongPassword(String password) {
  final regex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&]).{8,}$',
  );
  return regex.hasMatch(password);
}
```

**Problems**:
- Called AFTER form validation passes
- No error message until after form submit
- Only validates on button press (not real-time)
- Backend doesn't validate password strength (CRITICAL)
- Special character set is limited (@$!%*?&)

**Missing validator checks**:
- ✗ No client-side real-time feedback
- ✗ No password length validator in TextFormField
- ✗ Backend accepts ANY password on `/auth/register`

#### Issue 1.4: **No Confirm Password Field (Signup)**
**Severity**: HIGH  
**Location**: `signup_page.dart`  
**Problem**: No password confirmation field. User can't verify typos. Common UX mistake.

#### Issue 1.5: **Missing Phone Number Validation**
**Severity**: MEDIUM  
**Location**: Not visible in signup but likely in backend  
**Problem**: Backend allows phone submission but no format validation visible in Flutter

#### Issue 1.6: **Backend Email Validation Missing**
**Severity**: CRITICAL  
**Location**: `routes/auth_routes.py` line 52-53
```python
if not data.get('email') or not data.get('password'):
    return {'message': 'Email and password are required'}, 400
```
**Problem**: Checks if email exists, but doesn't validate format. Allows:
- `notanemail`
- `test@` (stored in DB)
- SQL-like injection? (see security section)

---

## 2. AUTHENTICATION ERRORS - Server-side

### ✅ WORKING
- Incorrect credentials returns 401 (proper status)
- User not found is handled
- Token is generated on successful login

### ❌ ISSUES

#### Issue 2.1: **No "User Not Found" Distinction**
**Severity**: MEDIUM  
**Location**: `routes/auth_routes.py` line 84-85
```python
if not user or not check_password_hash(user.password_hash, data['password']):
    return {'message': 'Invalid email or password'}, 401
```
**Problem**: Combines "user not found" + "wrong password" in one message. This is GOOD for UX (prevents account enumeration) but backend doesn't log which one occurred.

#### Issue 2.2: **No Account Status Checks**
**Severity**: HIGH  
**Problem**: No checks for:
- ✗ Account locked (after N failed attempts)
- ✗ Email verified status
- ✗ Account suspended/disabled
- ✗ 2FA enabled (but not implemented)

Backend accepts login without any account status validation.

#### Issue 2.3: **No Rate Limiting on Login**
**Severity**: CRITICAL  
**Location**: Backend completely missing rate limiting  
**Impact**: 
- Brute-force attacks possible
- No throttling of failed attempts
- No CAPTCHA after N failures
- No IP-based rate limiting

#### Issue 2.4: **Duplicate Account on Race Condition**
**Severity**: HIGH  
**Location**: `routes/auth_routes.py` lines 62-63
```python
if User.query.filter_by(email=data['email']).first():
    return {'message': 'Email already exists'}, 400
```
**Problem**: 
- Check-then-insert pattern (TOCTOU race condition)
- Two simultaneous requests can bypass check
- Could create duplicate accounts if DB doesn't have unique constraint

**Fix**: Rely on DB unique constraint + proper error handling:
```python
try:
    db.session.add(user)
    db.session.commit()
except IntegrityError:
    db.session.rollback()
    return {'message': 'Email already registered'}, 409
```

---

## 3. SECURITY ISSUES - CRITICAL

### ❌ VULNERABILITIES FOUND

#### Issue 3.1: **Password Stored Improperly (HIGH RISK)**
**Severity**: CRITICAL  
**Location**: `routes/auth_routes.py` line 62
```python
password_hash=generate_password_hash(data['password'])
```
**Status**: ✓ Uses `werkzeug.security.generate_password_hash` (good)  

**BUT**: 
- ✗ No password complexity requirements enforced on backend
- ✗ Backend schema should validate min length
- ✗ No password history (user can't reuse old passwords)
- ✗ No password expiration policy

#### Issue 3.2: **No Input Sanitization / SQL Injection Risk**
**Severity**: HIGH  
**Problem**: Using SQLAlchemy ORM which prevents SQL injection, BUT:
- No input length limits enforced
- XSS risk if error messages echoed back unsanitized

#### Issue 3.3: **Password Sent in Plain Text (Login)**
**Severity**: CRITICAL  
**Location**: `api_service.dart` line 48-52
```dart
final response = await http.post(
  Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'email': email, 'password': password}),
);
```
**Problem**: 
- ✗ Password sent as plain JSON over HTTPS (proper)
- ✗ BUT if HTTPS is ever downgraded, password exposed
- ✓ HTTPS appears to be in use (good)
- ✗ No API request timeout specified (could hang indefinitely)

**Issue**: Missing timeout:
```dart
.timeout(const Duration(seconds: 10))  // ADD THIS
```

#### Issue 3.4: **Plain-Text Credentials in Secure Storage**
**Severity**: CRITICAL  
**Location**: `login_page.dart` lines 79-88
```dart
const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

await _storage.write(
    key: _rememberPasswordKey,
    value: _passwordController.text,  // ❌ STORING PASSWORD!
);
```
**Problem**: 
- Storing actual password in encrypted storage
- Even encrypted, this is AGAINST best practices
- Should only store tokens, not passwords
- If device compromised, attacker can extract password

**Fix**: NEVER store passwords. Store only tokens:
```dart
// DELETE THIS ENTIRELY
// await _storage.write(key: _rememberPasswordKey, value: password);

// KEEP THIS
await _storage.write(
    key: _rememberEmailKey,
    value: email,  // Safe to store email
);
```

#### Issue 3.5: **Token Storage Security**
**Severity**: MEDIUM  
**Location**: `api_service.dart` (checking for secure storage)  
**Problem**: 
- ✓ Token is saved (good)
- ? Need to verify it uses FlutterSecureStorage
- ✗ No token expiration check on app launch
- ✗ No token refresh mechanism visible

#### Issue 3.6: **No HTTPS Enforcement Check**
**Severity**: MEDIUM  
**Problem**: No certificate pinning or HTTPS enforcement in code. Vulnerable to MITM attacks on untrusted networks.

#### Issue 3.7: **Google Sign-In Server Client ID Exposed**
**Severity**: MEDIUM  
**Location**: `login_page.dart` line 451
```dart
serverClientId: '735051756678-ubgq2aj18vnd7567ec2cutvg860vt186.apps.googleusercontent.com',
```
**Problem**: Client ID is hardcoded in source. Not a secret, but best moved to config.

---

## 4. UI/UX VALIDATION BUGS

### ✅ WORKING
- Error banner shows on login (red background)
- Loading state prevents double-submit
- Password visibility toggle works
- Form validation shows errors on submit

### ❌ ISSUES

#### Issue 4.1: **No Real-Time Validation Feedback**
**Severity**: MEDIUM  
**Location**: Both forms  
**Problem**: 
- Validation only triggers on form submit
- User doesn't know password too weak until clicking button
- No field-level error feedback as they type

**Example**: User types `Test1!` - no error shown until submit

#### Issue 4.2: **Vague Error Messages**
**Severity**: MEDIUM  
**Location**: `login_page.dart` line 448
```dart
setState(() => _errorMessage = 'Login failed: ${e.toString()}');
```
**Problems**:
- Shows raw exception strings: `"NoSuchMethodError (type 'Null' is not a type of 'String')"`
- User sees confusing errors like "Connection timeout"
- Doesn't distinguish between:
  - "Invalid credentials" (user error)
  - "Server error" (temporary)
  - "Network error" (connectivity)

#### Issue 4.3: **No Password Requirements Display**
**Severity**: MEDIUM  
**Location**: `signup_page.dart`  
**Problem**: 
- Shows "Minimum 8 characters" in validator
- Doesn't show requirements for uppercase, number, special char
- User sees error AFTER typing password

**Fix**: Show requirements list with checkmarks:
```
✓ At least 8 characters
✗ One uppercase letter
✓ One number
✗ One special character (@$!%*?&)
```

#### Issue 4.4: **Form Doesn't Clear on Success**
**Severity**: LOW  
**Problem**: After successful login, still shows fields (but not accessible)

#### Issue 4.5: **No Button Disabled State During Validation Error**
**Severity**: LOW  
**Location**: Signup  
**Problem**: Submit button enabled even if form is invalid (relies on form validator)

---

## 5. BACKEND & API BUGS

### ✅ WORKING
- Returns proper HTTP status codes (400, 401, 500)
- Uses JWT tokens with expiration
- Password hashing with werkzeug

### ❌ ISSUES

#### Issue 5.1: **Validation Mismatch (Client ≠ Server)**
**Severity**: CRITICAL  
| Check | Client | Server | Match |
|-------|--------|--------|-------|
| Email format | contains `@` | ✗ NONE | ❌ MISMATCH |
| Password min length | 8 chars | ✗ NONE | ❌ MISMATCH |
| Password strength | regex required | ✗ NONE | ❌ MISMATCH |
| Email trim | Yes | ✗ No | ❌ MISMATCH |

**Impact**: Mobile user sends invalid data server accepts incorrectly. Or API client bypasses validation.

#### Issue 5.2: **Generic 500 Error Response**
**Severity**: MEDIUM  
**Location**: `routes/auth_routes.py` line 77
```python
except Exception as e:
    db.session.rollback()
    return {'message': f'Registration failed: {str(e)}'}, 500
```
**Problem**: 
- Leaks exception details to client
- User sees internal Python errors
- Example: `"registration failed: Column 'age' cannot be NULL"`

#### Issue 5.3: **No Input Length Limits**
**Severity**: MEDIUM  
**Problem**: 
- No max length on email (possible DOS)
- No max length on password
- No max length on name

**Recommended**: 
- Email: Max 254 chars
- Password: Max 128 chars
- Name: Max 100 chars

#### Issue 5.4: **Slow API, Duplicate Submissions**
**Severity**: MEDIUM  
**Location**: `api_service.dart`  
**Problem**: 
- No request timeout on signup
- If API is slow (5+ seconds), user clicks again
- Could submit multiple times before first completes

**Fix**: Add timeout:
```dart
final response = await http.post(
  // ...
).timeout(const Duration(seconds: 10));
```

#### Issue 5.5: **No Proper Status Code for Duplicate Email**
**Severity**: LOW  
**Location**: `routes/auth_routes.py` line 61
```python
if User.query.filter_by(email=data['email']).first():
    return {'message': 'Email already exists'}, 400
```
**Better**: Use 409 Conflict
```python
return {'message': 'Email already registered'}, 409
```

---

## 6. EDGE CASES - Often Missed

### ❌ NOT HANDLED

#### Issue 6.1: **Leading/Trailing Spaces**
**Severity**: MEDIUM  
**Problem**: 
- Login: spaces trimmed ✓
- Signup: spaces trimmed ✓  
- BUT: Validator doesn't check trimmed value, so "  " (spaces only) passes as "non-empty"

**Test**: Enter "   " (spaces) in email → validator says "required" but text isn't empty

#### Issue 6.2: **Case Sensitivity in Email**
**Severity**: LOW  
**Location**: Database query in `routes/auth_routes.py`
```python
user = User.query.filter_by(email=data['email']).first()
```
**Problem**: 
- `User@Gmail.com` and `user@gmail.com` treated as different users
- Best practice: Store emails lowercase

**Fix**: 
```python
email_normalized = data['email'].lower().strip()
user = User.query.filter_by(email=email_normalized).first()
```

#### Issue 6.3: **Very Long Input (Buffer Overflow)**
**Severity**: MEDIUM  
**Problem**: No length validation. User sends:
- Email: 10,000 characters
- Password: 10,000 characters
- Creates bloated JWT or slow processing

#### Issue 6.4: **Unicode/Emoji in Fields**
**Severity**: LOW  
**Problem**: No validation. Allows:
- Name: "User 🚀 Name" (might be OK)
- Email: "user+用户@example.com" (invalid email)
- Password: "П@$$ąord🔐" (valid but unusual)

#### Issue 6.5: **Autofill Issues (Browser)**
**Severity**: LOW  
**Location**: Mobile Flutter (less of an issue than web)  
**Problem**: Android autofill might insert wrong values, but less of an issue in Flutter

#### Issue 6.6: **Network Interruption During Submission**
**Severity**: HIGH  
**Problem**: 
- No timeout on signup
- No retry mechanism
- User clicks submit, network drops halfway
- No indication what happened

#### Issue 6.7: **Empty/Null Password Submission**
**Severity**: MEDIUM  
**Problem**: 
- Frontend validator: `v == null || v.length < 8`
- But form validator can be bypassed if controller clears
- Backend has check `if not data.get('password')` (good)

---

## 7. MOBILE-SPECIFIC ISSUES

### ✅ WORKING
- Keyboard overlay handled with SingleChildScrollView
- TextInputAction.next/done for keyboard navigation
- Password visibility toggle works

### ❌ ISSUES

#### Issue 7.1: **Keyboard Overlapping (Partially)**
**Severity**: LOW  
**Problem**: Long error messages might overlap soft keyboard on small screens

#### Issue 7.2: **Autofill Inserting Wrong Values**
**Severity**: MEDIUM  
**Problem**: 
- Android autofill might fill password field with wrong saved password
- No clear mechanism to validate this

**Fix**: Add autofill hints for both forms:
```dart
autofillHints: const [AutofillHints.email],
```

#### Issue 7.3: **Validation Not Triggering on Keyboard Submit**
**Severity**: MEDIUM  
**Location**: `signup_page.dart`  
**Problem**: 
- `TextInputAction.done` shown on password field
- But no `onFieldSubmitted` handler
- User presses "Done" on keyboard, form doesn't submit

#### Issue 7.4: **Slow Internet / Offline Mode**
**Severity**: HIGH  
**Problem**:
- ✗ No offline detection
- ✗ No graceful handling of slow responses
- ✗ No error message distinguishing network vs server error
- User submits form on 2G, no feedback for 15+ seconds

---

## 8. BEST PRACTICES - To Avoid Bugs

### ✅ IMPLEMENTED
- Validate on client + server (partially)
- Use regex for email (partially)
- Hash passwords with werkzeug
- Proper HTTP status codes (mostly)
- JWT tokens for auth

### ❌ MISSING

| Practice | Status | Location |
|----------|--------|----------|
| **Validate on BOTH client + server** | ⚠️ Partial | Email/password validation only on client |
| **Use strong regex for email** | ❌ Missing | `!v.contains('@')` too permissive |
| **Implement debouncing for API** | ❌ Missing | No debounce on multiple submissions |
| **Add rate limiting & CAPTCHA** | ❌ Missing | No rate limit or CAPTCHA after N failures |
| **Hash passwords (bcrypt)** | ✓ Done | werkzeug.security |
| **Normalize inputs (trim, lowercase)** | ⚠️ Partial | Trim done, but no lowercase for email |
| **Use proper HTTP status codes** | ⚠️ Partial | Some missing (409 for conflict) |
| **Token expiration check** | ⚠️ Unknown | Need to verify implementation |
| **Log authentication failures** | ❌ Missing | No audit logging for failed attempts |
| **Brute-force protection** | ❌ Missing | No account lockout after N failures |

---

## FIXES REQUIRED - Priority Order

### 🔴 CRITICAL (Fix Immediately)

1. **Remove password from secure storage** (Issue 3.4)
   - Delete password storage in `login_page.dart`
   - Keep only email storage

2. **Add server-side validation** (Issue 5.1)
   - Email format validation
   - Password strength validation
   - Input length limits

3. **Add rate limiting** (Issue 2.3)
   - Rate limit login attempts per IP
   - Return 429 Too Many Requests after failures

4. **Fix email validation regex** (Issue 1.1)
   - Use proper email regex on both client & server

5. **Add password confirmation field** (Issue 1.4)
   - Signup needs "Confirm Password" field

### 🟠 HIGH (Fix This Sprint)

6. **Add field-level real-time validation** (Issue 4.1)
   - Show password requirements as user types
   - Email format feedback inline

7. **Better error messages** (Issue 4.2)
   - Map error codes to user-friendly messages
   - Distinguish network vs server errors

8. **Add timeouts to all API calls** (Issues 3.3, 5.4)
   - Login, signup, password reset

9. **Handle race conditions** (Issue 2.4)
   - Use DB unique constraints
   - Catch IntegrityError properly

10. **Add input normalization** (Issues 6.2, 1.2)
    - Lowercase emails
    - Trim all fields in validators

### 🟡 MEDIUM (Fix Next Sprint)

11. Account status checks (locked, suspended)
12. Password history (can't reuse)
13. Offline detection / graceful degradation
14. Audit logging for auth failures
15. HTTPS enforcement / certificate pinning

### 🟢 LOW (Nice to Have)

16. Real-time sign-up email verification
17. 2FA / MFA support
18. Social login providers beyond Google

---

## Code Changes Required

### File 1: `lib/features/auth/presentation/pages/login_page.dart`

**Change 1: Remove password storage**
```dart
// DELETE THIS ENTIRE METHOD
Future<void> _saveOrClearCredentials() async {
  // ...
}

// UPDATE to only save email:
Future<void> _saveOrClearCredentials() async {
  if (_rememberMe) {
    await _storage.write(key: _rememberMeKey, value: 'true');
    await _storage.write(
      key: _rememberEmailKey,
      value: _emailController.text.trim().toLowerCase(),
    );
  } else {
    await _storage.delete(key: _rememberMeKey);
    await _storage.delete(key: _rememberEmailKey);
  }
}

// ADD to loadRemembered method - DELETE the password restoration
Future<void> _loadRememberedCredentials() async {
  final remembered = await _storage.read(key: _rememberMeKey);
  if (remembered == 'true') {
    final email = await _storage.read(key: _rememberEmailKey);
    if (mounted) {
      setState(() {
        _rememberMe = true;
        if (email != null) _emailController.text = email;
        // REMOVE: _passwordController.text = password;
      });
    }
  }
}
```

**Change 2: Add email validation helper**
```dart
static bool _isValidEmail(String email) {
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  return emailRegex.hasMatch(email);
}

// Update validator:
AnimatedInputField(
  controller: _emailController,
  label: 'Email Address',
  prefixIcon: Icons.email_outlined,
  keyboardType: TextInputType.emailAddress,
  textInputAction: TextInputAction.next,
  validator: (v) {
    final email = v?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!_isValidEmail(email)) return 'Please enter a valid email';
    return null;
  },
),
```

**Change 3: Add timeout to login**
```dart
try {
  final email = _emailController.text.trim().toLowerCase();
  final password = _passwordController.text;
  
  // Validate before sending
  if (email.isEmpty || password.isEmpty) {
    setState(() => _errorMessage = 'Email and password required');
    return;
  }
  if (!_isValidEmail(email)) {
    setState(() => _errorMessage = 'Please enter valid email');
    return;
  }
  
  await ApiService.login(email, password)
      .timeout(const Duration(seconds: 10));
  // ... rest of code
} on TimeoutException {
  setState(() => _errorMessage = 'Request timed out. Check your connection.');
} catch (e) {
  // ... existing error handling
}
```

### File 2: `lib/features/auth/presentation/pages/signup_page.dart`

**Change 1: Add confirm password field**
```dart
final confirmPasswordController = TextEditingController();
bool obscureConfirmPassword = true;

// Add after password field:
const SizedBox(height: 16),
_inputField(
  controller: confirmPasswordController,
  label: 'Confirm Password',
  icon: Icons.lock,
  obscureText: obscureConfirmPassword,
  suffixIcon: IconButton(
    icon: Icon(
      obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
    ),
    onPressed: () {
      setState(() {
        obscureConfirmPassword = !obscureConfirmPassword;
      });
    },
  ),
  validator: (v) {
    if (v == null || v.isEmpty) return 'Please confirm password';
    if (v != passwordController.text) return 'Passwords do not match';
    return null;
  },
),
```

**Change 2: Add email validation**
```dart
static bool _isValidEmail(String email) {
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
  );
  return emailRegex.hasMatch(email);
}

// Update email field validator:
_inputField(
  controller: emailController,
  label: 'Email',
  icon: Icons.email,
  keyboardType: TextInputType.emailAddress,
  validator: (v) {
    final email = v?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!_isValidEmail(email)) return 'Please enter a valid email format';
    return null;
  },
),
```

**Change 3: Update password strength message**
```dart
if (!isStrongPassword(password)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Password must contain:\n'
        '• At least 8 characters\n'
        '• Uppercase letter (A-Z)\n'
        '• Lowercase letter (a-z)\n'
        '• Number (0-9)\n'
        '• Special character (@\$!%*?&)',
      ),
      backgroundColor: AppTheme.error,
      duration: Duration(seconds: 4),
    ),
  );
  return;
}
```

**Change 4: Add timeout to signup**
```dart
try {
  await ApiService.signup(
    name: nameController.text.trim(),
    email: emailController.text.trim().toLowerCase(),
    password: password,
    age: ageController.text.isNotEmpty
        ? int.tryParse(ageController.text)
        : null,
    sex: selectedSex,
  ).timeout(const Duration(seconds: 10));
  // ... rest
} on TimeoutException {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Request timed out. Please check your internet connection.'),
      backgroundColor: AppTheme.error,
    ),
  );
}
```

**Change 5: Dispose confirm password controller**
```dart
@override
void dispose() {
  nameController.dispose();
  emailController.dispose();
  passwordController.dispose();
  confirmPasswordController.dispose();  // ADD
  ageController.dispose();
  super.dispose();
}
```

### File 3: `lib/services/api_service.dart`

**Change 1: Add timeouts to login**
```dart
static Future<AuthResponse> login(String email, String password) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email.toLowerCase().trim(),  // Normalize
      'password': password,
    }),
  ).timeout(const Duration(seconds: 10));  // ADD TIMEOUT

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final auth = AuthResponse.fromJson(data);
    await saveToken(auth.token);
    return auth;
  }

  _throwReadableError(response);
}
```

**Change 2: Add timeouts to signup**
```dart
static Future<AuthResponse> signup({
  required String name,
  required String email,
  required String password,
  int? age,
  String? sex,
}) async {
  final response = await http.post(
    Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signupEndpoint}'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': name.trim(),
      'email': email.toLowerCase().trim(),  // Normalize
      'password': password,
      if (age != null) 'age': age,
      if (sex != null) 'sex': sex,
    }),
  ).timeout(const Duration(seconds: 10));  // ADD TIMEOUT

  if (response.statusCode == 201) {
    final data = jsonDecode(response.body);
    final auth = AuthResponse.fromJson(data);
    await saveToken(auth.token);
    return auth;
  }

  _throwReadableError(response);
}
```

### File 4: `netracare_backend/routes/auth_routes.py`

**Change 1: Add comprehensive backend validation**
```python
import re
from functools import wraps
from flask import abort

def validate_email_format(email: str) -> bool:
    """Validate email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def validate_password_strength(password: str) -> tuple[bool, str]:
    """
    Validate password strength.
    Returns (is_valid, error_message)
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters"
    if not re.search(r'[a-z]', password):
        return False, "Password must contain a lowercase letter"
    if not re.search(r'[A-Z]', password):
        return False, "Password must contain an uppercase letter"
    if not re.search(r'\d', password):
        return False, "Password must contain a number"
    if not re.search(r'[@$!%*?&]', password):
        return False, "Password must contain a special character (@$!%*?&)"
    return True, ""

@auth_ns.route('/register')
class Register(Resource):
    """User registration endpoint"""
    
    @auth_ns.expect(register_model)
    def post(self):
        """Register a new user"""
        try:
            data = request.get_json()
            
            # Normalize and validate input
            email = data.get('email', '').strip().lower()
            password = data.get('password', '').strip()
            name = data.get('full_name', '') or data.get('username', '')
            name = name.strip() if name else ''
            
            # Validate all required fields
            if not email or not password or not name:
                return {
                    'message': 'Name, email and password are required'
                }, 400
            
            # Validate input lengths
            if len(email) > 254:
                return {'message': 'Email too long (max 254 characters)'}, 400
            if len(password) > 128:
                return {'message': 'Password too long (max 128 characters)'}, 400
            if len(name) > 100:
                return {'message': 'Name too long (max 100 characters)'}, 400
            
            # Validate email format
            if not validate_email_format(email):
                return {'message': 'Invalid email format'}, 400
            
            # Validate password strength
            is_strong, error_msg = validate_password_strength(password)
            if not is_strong:
                return {'message': error_msg}, 400
            
            # Check if user exists (case-insensitive)
            if User.query.filter_by(email=email).first():
                return {'message': 'Email already registered'}, 409
            
            # Create new user
            user = User(
                name=name,
                email=email,
                password_hash=generate_password_hash(password)
            )
            
            db.session.add(user)
            try:
                db.session.commit()
            except IntegrityError:
                db.session.rollback()
                return {'message': 'Email already registered'}, 409
            
            return {
                'message': 'User registered successfully',
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email,
                    'created_at': user.created_at.isoformat() if user.created_at else None
                }
            }, 201
            
        except Exception as e:
            db.session.rollback()
            # Log the full error server-side, return generic message to client
            app.logger.error(f'Registration error: {str(e)}')
            return {
                'message': 'Registration failed. Please try again.'
            }, 500


@auth_ns.route('/login')
class Login(Resource):
    """User login endpoint"""
    
    @auth_ns.expect(login_model)
    def post(self):
        """Login with email and password"""
        try:
            data = request.get_json()
            
            # Normalize email
            email = data.get('email', '').strip().lower()
            password = data.get('password', '')
            
            # Validate required fields
            if not email or not password:
                return {
                    'message': 'Email and password are required'
                }, 400
            
            # Validate input length
            if len(email) > 254 or len(password) > 128:
                return {'message': 'Invalid input'}, 400
            
            # Find user
            user = User.query.filter_by(email=email).first()
            
            # Check password (whether user exists or not)
            if not user or not check_password_hash(user.password_hash, password):
                return {
                    'message': 'Invalid email or password'
                }, 401
            
            # Check account status (if such fields exist)
            # if not user.is_active:
            #     return {'message': 'Account is inactive'}, 403
            
            # Generate JWT token
            token = jwt.encode({
                'user_id': user.id,
                'exp': datetime.utcnow() + timedelta(days=7)
            }, BaseConfig.SECRET_KEY, algorithm='HS256')
            
            return {
                'message': 'Login successful',
                'token': token,
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email
                }
            }, 200
            
        except Exception as e:
            app.logger.error(f'Login error: {str(e)}')
            return {
                'message': 'Login failed. Please try again.'
            }, 500
```

---

## Testing Checklist

### Manual Testing
- [ ] Sign up with invalid email (missing @, domain)
- [ ] Sign up with weak password (no uppercase, no special char, <8 chars)  
- [ ] Sign up with password ≠ confirm password
- [ ] Login with non-existent email
- [ ] Login with correct email, wrong password
- [ ] Signup with email already registered
- [ ] Try to brute-force login (10+ attempts)
- [ ] Submit form with all spaces in email
- [ ] Submit form with UPPERCASE email, then login with lowercase
- [ ] Enter very long input (1000+ chars)
- [ ] Disconnect network during login submission
- [ ] Uncheck "Remember me" and verify password not saved
- [ ] Clear app data and re-login

### Automated Testing
```dart
void main() {
  group('Email Validation', () {
    test('valid email passes', () {
      expect(_isValidEmail('user@example.com'), true);
    });
    
    test('missing @ fails', () {
      expect(_isValidEmail('userexample.com'), false);
    });
    
    test('missing domain fails', () {
      expect(_isValidEmail('user@'), false);
    });
  });
  
  group('Password Strength', () {
    test('weak password fails', () {
      expect(isStrongPassword('weak'), false);
    });
    
    test('strong password passes', () {
      expect(isStrongPassword('MyPass123!'), true);
    });
  });
}
```

---

## Summary Table

| Category | Issues | Severity | Status |
|----------|--------|----------|--------|
| **Input Validation** | 6 | CRITICAL | ❌ Needs work |
| **Auth Errors** | 4 | HIGH | ❌ Missing checks |
| **Security** | 7 | CRITICAL | 🔴 Major fixes needed |
| **UI/UX** | 5 | MEDIUM | ⚠️ Partial |
| **Backend** | 5 | CRITICAL | ❌ Missing validation |
| **Edge Cases** | 7 | MEDIUM | ❌ Not handled |
| **Mobile** | 4 | MEDIUM | ⚠️ Partial |
| **Best Practices** | 10 | VARIES | ⚠️ Partial |
| **TOTAL** | **48** | **CRITICAL** | **ACTION REQUIRED** |

---

## Conclusion

The login/signup system has **basic functionality** but **significant validation gaps**. Most critically:

1. ✗ Passwords stored in secure storage (CRITICAL)
2. ✗ No server-side validation (CRITICAL)
3. ✗ No rate limiting / brute force protection (CRITICAL)
4. ✗ Email validation too permissive (HIGH)
5. ✗ No confirm password field (HIGH)
6. ✗ Missing password strength display (MEDIUM)

**Estimated Fix Time**: 3-4 hours for all critical items, 1 day for all issues

**Next Steps**:
1. Implement all code changes above
2. Run manual testing checklist
3. Deploy with the fixes
4. Add automated tests for validation
