# PROMPT 03 — Login, Forgot Password, Authenticator (design/01_login_security.jpg)

Follow `CLAUDE.md`. Open `design/01_login_security.jpg` and build its 3 screens exactly. Also build a native splash screen.

## Splash
Purple IQ logo centred on the light lavender background for about 1 second, then go to Login. If "Remember me" was ticked in this session, go straight to Home.

## Screen 1 (left): Sign in
- Top row: logo `assets/images/logo_on_light.png` + "Purple IQ" (purple, bold). A language pill "🌐 English ▾" on the right opens a bottom sheet with English and العربية. Choosing Arabic shows a SnackBar "Arabic will be available in a later release".
- Hero: big "Asset**360**" (Asset navy, 360 violet); "Track | Manage | Optimize"; "Complete Asset Lifecycle Management in your hands."; illustration on the right using `assets/images/login_hero.jpg` (fade its left edge into the background).
- White card sheet with rounded top: "Sign in to Asset**360**", subtitle "Access your assets, operations and insights".
  - Username field (person icon) and Password field (lock icon, eye toggle shows/hides the password).
  - "Remember me" checkbox and a "Forgot Username or Password?" link.
  - "Sign In →" primary button.
  - "or" divider, then "Sign in with Google" and "Sign in with Microsoft" outlined buttons with their logos. Draw the logos with simple coloured shapes or icons, not copied brand images.
  - Footer: "New to Asset360? Contact your administrator." Tapping it opens a sheet with admin contact info (admin@purpleiq.ae, +971 4 000 0000) and Copy buttons.
- Behaviour:
  - Validate that fields aren't empty (inline red errors).
  - Correct credentials (`rex.kumar` / `Asset@360`, or email `rex.kumar@purpleiq.ae`) show a loading spinner on the button for 1 second, then go to the Authenticator screen.
  - Wrong credentials show "Invalid username or password". After 5 wrong tries, lock for 30 seconds with a countdown on the button.
  - Google / Microsoft: show a 1.5-second loading dialog "Connecting to Google…", then go to the Authenticator screen.

## Screen 2 (middle): Forgot Username or Password?
- Back arrow, centred logo, the envelope/lock illustration (build with icons and soft circles), title, description, email field.
- "I need help with:" radio cards: "Reset my password" (default) and "Recover my username".
- "Send Instructions →" validates the email format. A valid email shows a loading state, then a success bottom sheet: "Check your inbox — we sent instructions to r***@purpleiq.ae" with a "Back to Login" button.
- "‹ Back to Login" link.

## Screen 3 (right): Enter Authenticator Code
- Back arrow, logo, shield illustration with a multicolour asterisk badge (draw it; don't use the Google logo).
- Title "Enter Authenticator Code" and description.
- An "Open Google Authenticator" row. Tapping it tries to open the Authenticator app; if that isn't possible, show a SnackBar "Open your authenticator app and find Purple IQ – Asset360".
- 6 separate boxes: auto-advance, paste support, backspace goes back, numeric keyboard, auto-submit on the 6th digit.
- "Verify Code →":
  - `123456` succeeds → Home, with a smooth transition.
  - A wrong code shakes the boxes and shows "Invalid code. 4 attempts left". After 5 wrong tries, return to Login with a message.
- Change the design's "Didn't receive the code?" to **"Can't access your authenticator?"** (authenticator codes aren't sent). The link "Use a different method" opens a sheet with "Send code by email" and "Use a backup code", both simulated. Email shows "Code sent to r***@purpleiq.ae (demo: use 123456)".

## Session
- Store the logged-in state in a Riverpod provider.
- go_router redirects to Login when logged out.
- Logout (from More) clears it and returns to Login.

## Done when
All 3 screens match the design. Every link, button, toggle and field behaves as above, and the full path Login → Authenticator → Home works on the phone.
